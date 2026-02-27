module vircc
import kutlayozger.chalk
import pcre

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
  
  if irc_conn.color {
    if !command.is_int() {
      match command {
        "PRIVMSG" {
          // CTCP ACTION
          if trailing.starts_with("\x01ACTION ") && trailing.ends_with("\x01") {
            action_text := trailing[8..trailing.len - 1]
            return "* ${chalk.bold(cnick)} ${action_text}"
          }
          return chalk.bold("<${cnick}> ${trailing}")
        }

        "NOTICE" {
          if nick.len > 0 {
            return "-${cnick}- ${trailing}"
          }
          return "${trailing}"
        }

        "JOIN" {
          return "${cnick} has joined ${if trailing.len > 0 { trailing } else {target} }"
        }

        "PART" {
          if trailing.len > 0 {
            return "${cnick} has left ${target} (${trailing})"
          }
          return "${cnick} has left ${target}"
        }

        "QUIT" {
          if trailing.len > 0 {
            return "${cnick} has quit (${trailing})"
          }
          return "${cnick} has quit"
        }

        "KICK" {
          parts := line.split(" ")
          if parts.len >= 4 {
            victim := parts[3]
            mut msg := "${cnick} kicked ${chalk.cyan(victim)} from ${chalk.cyan(target)}"
            if trailing.len > 0 {
              msg += " (${trailing})"
            }
            return msg
          }
        }

        "NICK" {
          newnick := if trailing.len > 0 { trailing } else { target }
          return "${cnick} is now known as ${chalk.cyan(newnick)}"
        }

        "PING" {
          irc_conn.tcp.write("PONG ${trailing}".bytes())!
          return ""
        }

        else {
          return "-!- [${command}] ${trailing}"
        }
      }
    } else if command.is_int() {
      match command {
        "353" {
          names := trailing.split_by_space()
          mut ret := ""
          for name in names { ret += "[${name}]" }
          return "Users: ${ret}"
        }
        
        "366" {
          return "userlist complete"
        }

        else {
          return chalk.dim("[${command}] ${trailing}")
        }
      }
    }
  } else {
    if !command.is_int() {
      match command {
        "PRIVMSG" {
          // CTCP ACTION
          if trailing.starts_with("\x01ACTION ") && trailing.ends_with("\x01") {
            action_text := trailing[8..trailing.len - 1]
            return "* ${cnick} ${action_text}"
          }
          return "<${cnick}> ${trailing}"
        }

        "NOTICE" {
          if nick.len > 0 {
            return "-${cnick}- ${trailing}"
          }
          return "${trailing}"
        }

        "JOIN" {
          return "${cnick} has joined ${if trailing.len > 0 { trailing } else {target} }"
        }

        "PART" {
          if trailing.len > 0 {
            return "${cnick} has left ${target} (${trailing})"
          }
          return "${cnick} has left ${target}"
        }

        "QUIT" {
          if trailing.len > 0 {
            return "${cnick} has quit (${trailing})"
          }
          return "${cnick} has quit"
        }

        "KICK" {
          parts := line.split(" ")
          if parts.len >= 4 {
            victim := parts[3]
            mut msg := "${cnick} kicked ${victim} from ${target}"
            if trailing.len > 0 {
              msg += " (${trailing})"
            }
            return msg
          }
        }

        "NICK" {
          newnick := if trailing.len > 0 { trailing } else { target }
          return "${cnick} is now known as ${newnick}"
        }

        "PING" {
          irc_conn.tcp.write("PONG ${trailing}".bytes())!
          return ""
        }

        else {
          return "-!- [${command}] ${trailing}"
        }
      }
    } else if command.is_int() {
      match command {
        "353" {
          names := trailing.split_by_space()
          mut ret := ""
          for name in names { ret += "[${name}] " }
          return "Users: ${ret}"
        }
        
        "366" {
          return "userlist complete"
        }

        else {
          return "[${command}] ${trailing}"
        }
      }
    }
  }

  return ""
}
