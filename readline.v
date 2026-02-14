module vircc

import kutlayozger.chalk

pub fn (mut irc_conn IrcConn) readline() !string {
  // Read a single line from the TCP connection
  raw_line := irc_conn.tcp.read_line()
  line := raw_line.trim_space()

  if line.len == 0 {
    return "" // ignore empty messages
  }

  mut prefix := ""
  mut command := ""
  mut params := []string{}
  mut trailing := ""

  mut rest := line

  // Check for optional prefix
  if rest.starts_with(":") {
    space_idx := rest.index_after(" ", 1) or { return line } // malformed, return raw
    prefix = rest[1..space_idx]
    rest = rest[space_idx + 1..]
  }

  // Extract command
  space_idx := rest.index(" ") or { rest.len }
  command = rest[..space_idx]
  rest = if space_idx < rest.len { rest[space_idx + 1..] } else { "" }

  // Extract params & trailing
  if rest.len > 0 {
    mut parts := rest.split(" ")
    for i, p in parts {
      if p.starts_with(":") {
        trailing = p[1..] + if i < parts.len - 1 { " " + parts[i + 1..].join(" ") } else { "" }
        break
      } else {
        params << p
      }
    }
  }

  // Build human-readable output
  mut output := ""
  if irc_conn.is_terminal == true {
    if command == "PRIVMSG" && params.len > 0 {
      target := params[0]
      sender := if prefix.len > 0 { prefix.split("!")[0] } else { "unknown" }
      output = chalk.green("<${sender}:${target}> ${trailing}")
    } else if command == "NOTICE" && params.len > 0 {
      _ := params[0]
      sender := if prefix.len > 0 { prefix } else { "server" }
      output = chalk.light_red("-${sender}- ${trailing}")
    } else if command in ["JOIN", "PART", "QUIT"] {
      user := if prefix.len > 0 { prefix.split("!")[0] } else { "unknown" }
      ch := if params.len > 0 { params[0] } else { trailing }
      output = chalk.magenta("${user} ${command} ${ch}")
    } else if command.len == 3 && command[0].is_digit() {
      // numeric replies
      output = chalk.dark_gray("-${command}- ${trailing}")
    } else if command == "PING" {
      irc_conn.tcp.write("PONG :${trailing}".bytes())!
      output = chalk.blue("Server pinged us, responding with: PONG :${trailing}")
    } else if command == "PONG" {
    } else {
      // fallback
      output = chalk.red("${line}")
    }
  } else if irc_conn.is_terminal == false {
    if command == "PRIVMSG" && params.len > 0 {
    target := params[0]
    sender := if prefix.len > 0 { prefix.split("!")[0] } else { "unknown" }
    output = "<${sender}:${target}> ${trailing}"
  } else if command == "NOTICE" && params.len > 0 {
    _ := params[0]
    sender := if prefix.len > 0 { prefix } else { "server" }
    output = "-${sender}- ${trailing}"
  } else if command in ["JOIN", "PART", "QUIT"] {
    user := if prefix.len > 0 { prefix.split("!")[0] } else { "unknown" }
    ch := if params.len > 0 { params[0] } else { trailing }
    output = "${user} ${command} ${ch}"
  } else if command.len == 3 && command[0].is_digit() {
    // numeric replies
    output = "-${command}- ${trailing}"
  } else if command == "PING" {
    irc_conn.tcp.write("PONG :${trailing}".bytes())!
    output = "Server pinged us, responding with: PONG :${trailing}"
  } else if command == "PONG" {
  } else {
    // fallback
    output = "${line}"
  }
  }

  return output
}
