module vircc

import net

pub fn connect(ip string, port string, nick string) IrcConn
{
  mut conn := net.dial_tcp("${ip}:${port}") or { exit(1) }
  $if debug { println("${IrcConn{ tcp: conn nick: nick }}") }
  $if debug { println("${ip}:${port}") }
  return IrcConn{
    tcp: conn
    nick: nick
    channel: ""
    is_running: true
  }
}

pub fn (mut irc_conn IrcConn) writeline(input string) !
{
  /*
  if input.len == 0 {
    return
  }
  */

  // COMMANDS start with /
  if input.starts_with("/") {
    parts := input[1..].split(" ") // remove leading /

    match parts[0] {
      "join" {
        if parts.len > 1 {
          irc_conn.tcp.write("JOIN ${parts[1]}\r\n".bytes())!
          irc_conn.channel = parts[1]
        }
      }
      "part" {
        if parts.len > 1 {
          irc_conn.tcp.write("PART ${irc_conn.channel}\r\n".bytes())!
          irc_conn.channel = ""
        }
      }
      "nick" {
        if parts.len > 1 {
          irc_conn.tcp.write("NICK ${parts[1]}\r\n".bytes())!
          irc_conn.nick = parts[1]
        }
      }
      "quit" {
        irc_conn.tcp.write("QUIT :leaving\r\n".bytes())!
        irc_conn.is_running = false
        irc_conn.disconnect() or {}
        return
      }
      else {
        println("Unknown command.")
      }
    }
  } else {
    // Print normal messages
    irc_conn.tcp.write("PRIVMSG ${irc_conn.channel} :${input}\r\n".bytes())!
  }
}

// Helper functions
pub fn (mut irc_conn IrcConn) login() !
{
  // Write the nickname to the server
  irc_conn.tcp.write("NICK ${irc_conn.nick}\r\n".bytes())!
  $if debug { println("NICK ${irc_conn.nick}") }

  // Write the username to the server
  irc_conn.tcp.write("USER ${irc_conn.nick} 0 * :${irc_conn.nick} IRC Client\r\n".bytes())!
  $if debug { println("USER ${irc_conn.nick} 0 * :${irc_conn.nick} IRC Client")}
}

pub fn (mut irc_conn IrcConn) readline() !string {
  line := irc_conn.tcp.read_line()
  if line.starts_with("PING") {
    irc_conn.tcp.write("PONG ${line.split(" ")[1]}".bytes())!
    println("PONG ${line.split(" ")[1]}")
  }
  return line
}

pub fn (mut irc_conn IrcConn) disconnect() !
{
  $if debug { println("Goobai") }
  irc_conn.tcp.close()!
}

// -- Structs --
pub struct IrcConn {
pub mut:
  tcp         net.TcpConn
  nick        string
  channel     string
  is_running  bool
}
