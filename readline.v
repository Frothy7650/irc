module vircc
import kutlayozger.chalk
import regex.pcre

pub fn (mut irc_conn IrcConn) readline() !string {
  raw_line := irc_conn.tcp.read_line()
  line := raw_line.trim_space()
  if line.len == 0 { return "" }

  mut prefix := ""
  mut command := ""
  mut target := ""
  mut trailing := ""

  // Regex:
  // 1 = prefix (optional)
  // 2 = command
  // 3 = middle params (optional)
  // 4 = trailing (optional)
  regex_pattern := r"^(?::([^ ]+)\s+)?([A-Za-z]+|\d{3})(?:\s([^:]+))?(?:\s:(.*))?$"

  r := pcre.new_regex(regex_pattern, 0) or {
    return error("regex compile failed")
  }

  if m := r.match_str(line, 0, 0) {
    prefix   = m.get(1) or { "" }
    command  = m.get(2) or { "" }

    middle   := m.get(3) or { "" }
    trailing = m.get(4) or { "" }

    if middle.len > 0 {
      parts := middle.split(" ")
      if parts.len > 0 {
        target = parts[0]
      }
    }
  } else {
    return ""
  }

  // Extract nick from prefix
  mut nick := prefix
  if i := nick.index("!") {
    nick = nick[..i]
  }

  cnick := if nick.len > 0 { chalk.cyan(nick) } else { "" }

  // === WITH COLOR ===
  if irc_conn.color {
    if !command.is_int() {
      match command {
        "NOTICE" {
          if nick.len > 0 { return chalk.underline("-${cnick}- ${trailing}") }
          return chalk.underline("${trailing}")
        }

        "PRIVMSG" {
          if trailing.starts_with("\x01ACTION ") && trailing.ends_with("\x01") {
            action_text := trailing[8..trailing.len - 1]
            return "* ${chalk.bold(cnick)} ${action_text}"
          }
          return chalk.bold("<${cnick}> ${trailing}")
        }

        "PING" {
          irc_conn.tcp.write("PONG ${trailing}".bytes())!
          return ""
        }

        "PONG" {
          if trailing.len > 0 { return "${trailing} responded to ping" }
        }

        "JOIN" {
          return "${cnick} has joined ${if trailing.len > 0 { trailing } else { target } }"
        }

        "PART" {
          if trailing.len > 0 { return "${cnick} has left ${target} (${trailing})" }
          return "${cnick} has left ${target}"
        }

        "QUIT" {
          if trailing.len > 0 { return "${cnick} has quit (${trailing})" }
          return "${cnick} has quit"
        }

        "NICK" {
          newnick := if trailing.len > 0 { trailing } else { target }
          return "${cnick} is now known as ${chalk.cyan(newnick)}"
        }

        "KICK" {
          parts := line.split(" ")
          if parts.len >= 4 {
            victim := parts[3]
            mut msg := "${cnick} kicked ${chalk.cyan(victim)} from ${chalk.cyan(target)}"
            if trailing.len > 0 { msg += " (${trailing})" }
            return msg
          }
        }

        "MODE" {
          return "${cnick} changed mode: ${trailing}"
        }

        "TOPIC" {
          return "${cnick} set topic for ${target}: ${trailing}"
        }

        else {
          return "-!- [${command}] ${trailing}"
        }
      }
    } else if command.is_int() {
      match command {
        "001", "002", "003", "004", "005" { return trailing }
        "200", "201", "202", "203", "204", "205", "206", "207", "208", "209" { return chalk.dim("[${command}] ${trailing}") }
        "251","252","253","254","255" { return chalk.dim("[${command}] ${trailing}") }
        "301","305","306","311","312","313","317","318","319" { return chalk.dim("[${command}] ${trailing}") }
        "322","323","324","331","332","341","346","347","348","349" { return chalk.dim("[${command}] ${trailing}") }
        "353" {
          names := trailing.split_by_space()
          mut ret := ""
          for name in names { ret += "[${name}] " }
          return "Users: ${ret}"
        }
        "366" { return "userlist complete" }
        "372","375","376" { return chalk.dim("${trailing}") }
        "421","422","431","432","433","436","441","442","443","451","461","462","463","464","465","467","471","473","475","481","482","501","502" {
          return chalk.red("[${command}] ${trailing}")
        }
        else { return chalk.dim("[${command}] ${trailing}") }
      }
    }
  }


  // === WITHOUT COLOR ===


  else {
    if !command.is_int() {
      match command {
        "NOTICE" {
          if nick.len > 0 { return "-${cnick}- ${trailing}" }
          return "${trailing}"
        }

        "PRIVMSG" {
          if trailing.starts_with("\x01ACTION ") && trailing.ends_with("\x01") {
            action_text := trailing[8..trailing.len - 1]
            return "* ${cnick} ${action_text}"
          }
          return "<${cnick}> ${trailing}"
        }

        "JOIN" { return "${cnick} has joined ${if trailing.len > 0 { trailing } else { target } }" }
        "PART" { if trailing.len > 0 { return "${cnick} has left ${target} (${trailing})" } return "${cnick} has left ${target}" }
        "QUIT" { if trailing.len > 0 { return "${cnick} has quit (${trailing})" } return "${cnick} has quit" }
        "NICK" { newnick := if trailing.len > 0 { trailing } else { target }; return "${cnick} is now known as ${newnick}" }
        "KICK" {
          parts := line.split(" ")
          if parts.len >= 4 {
            victim := parts[3]
            mut msg := "${cnick} kicked ${victim} from ${target}"
            if trailing.len > 0 { msg += " (${trailing})" }
            return msg
          }
        }
        "MODE" { return "${cnick} changed mode: ${trailing}" }
        "TOPIC" { return "${cnick} set topic for ${target}: ${trailing}" }
        "PING" { irc_conn.tcp.write("PONG ${trailing}".bytes())!; return "" }
        else { return "-!- [${command}] ${trailing}" }
      }
    } else if command.is_int() {
      match command {
        "001","002","003","004","005" { return trailing }
        "353" {
          names := trailing.split_by_space()
          mut ret := ""
          for name in names { ret += "[${name}] " }
          return "Users: ${ret}"
        }
        "366" { return "userlist complete" }
        "200", "201", "202", "203", "204", "205", "206", "207", "208", "209","251","252","253","254","255","301","305","306","311","312","313","317","318","319","322","323","324","331","332","341","346","347","348","349","372","375","376" {
          return "[${command}] ${trailing}"
        }
        "421","422","431","432","433","436","441","442","443","451","461","462","463","464","465","467","471","473","475","481","482","501","502" {
          return "[${command}] ${trailing}"
        }
        else { return "[${command}] ${trailing}" }
      }
    }
  }

  return ""
}
