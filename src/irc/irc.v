module vircc

import sync
import net
import os

pub fn connect(ip string, port string) IrcConn
{
  mut conn := net.dial_tcp("${ip}:${port}") or { exit(1) }
  nick := os.input("Enter your nickname: ")
  $if debug { println("${IrcConn{ tcp: conn nick: nick }}") }
  $if debug { println("${ip}:${port}") }
  return IrcConn{
    tcp: conn
    nick: nick
    channel: ""
    is_running: true
  }
}

pub fn (mut irc_conn IrcConn) login() !
{
  // Write the nickname to the server
  irc_conn.tcp.write("NICK ${irc_conn.nick}\r\n".bytes())!
  $if debug { println("NICK ${irc_conn.nick}") }

  // Write the username to the server
  irc_conn.tcp.write("USER ${irc_conn.nick} 0 * :${irc_conn.nick} IRC Client\r\n".bytes())!
  $if debug { println("USER ${irc_conn.nick} 0 * :${irc_conn.nick} IRC Client")}
}

pub fn (mut irc_conn IrcConn) handle() !
{
    mut wg := sync.WaitGroup{}
    wg.add(1)

    go fn [mut irc_conn, mut wg]() {
        // handle the possible error from printlines
        irc_conn.readlines() or { panic(error("FUck")) }
        wg.done()
    }()

    irc_conn.login()!
    irc_conn.writelines()!

    if irc_conn.is_running == false { return }
    wg.wait() // wait for the goroutine
}

pub fn (mut irc_conn IrcConn) writelines() !
{
  for {
    input := os.input('')

    if input.len == 0 {
      continue
    }

    // COMMANDS start with /
    if input.starts_with('/') {
      parts := input[1..].split(' ') // remove leading /

      match parts[0] {
        'join' {
          if parts.len > 1 {
            irc_conn.tcp.write('JOIN ${parts[1]}\r\n'.bytes())!
            irc_conn.channel = parts[1]
          }
        }
        'part' {
          if parts.len > 1 {
            irc_conn.tcp.write('PART ${parts[1]}\r\n'.bytes())!
            irc_conn.channel = ""
          }
        }
        'nick' {
          if parts.len > 1 {
            irc_conn.tcp.write('NICK ${parts[1]}\r\n'.bytes())!
            irc_conn.nick = parts[1]
          }
        }
        'quit' {
          irc_conn.tcp.write('QUIT :leaving\r\n'.bytes())!
          irc_conn.is_running = false
          irc_conn.disconnect() or {}
          return
        }
        else {
          println('Unknown command.')
        }
      }

      continue
    }

    // NORMAL MESSAGE (send to current channel manually for now)
    // Replace #main with whatever channel you're using
    irc_conn.tcp.write('PRIVMSG ${irc_conn.channel} :${input}\r\n'.bytes())!
  }
}

// -- Simple automation functions
pub fn (mut irc_conn IrcConn) readlines() !
{
  for irc_conn.is_running {
    msg := irc_conn.tcp.read_line()
    print(msg)
  }
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
