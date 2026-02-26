module vircc

import kutlayozger.chalk
import pcre

pub fn (mut irc_conn IrcConn) readline() !string {
  raw_line := irc_conn.tcp.read_line()
  line := raw_line.trim_space()
  if line.len == 0 { return '' }

  // ================= IRC PARSE =================
  mut prefix := ''
  mut command := ''
  mut target := ''
  mut trailing := ''

  // Regex:
  // 1 = prefix (optional)
  // 2 = command
  // 3 = middle params (optional)
  // 4 = trailing (optional)
  regex_pattern := r'^(?::([^ ]+)\s+)?([A-Za-z]+|\d{3})(?:\s([^:]+))?(?:\s:(.*))?$'

  r := pcre.new_regex(regex_pattern, 0) or {
    return error('regex compile failed')
  }

  if m := r.match_str(line, 0, 0) {
    prefix   = m.get(1) or { '' }
    command  = m.get(2) or { '' }

    middle   := m.get(3) or { '' }
    trailing = m.get(4) or { '' }

    if middle.len > 0 {
      parts := middle.split(' ')
      if parts.len > 0 {
        target = parts[0]
      }
    }
  } else {
    return ''
  }

  // ================= IRSSI STYLE OUTPUT =================

  // Extract nick from prefix
  mut nick := prefix
  if i := nick.index('!') {
    nick = nick[..i]
  }

  cnick := if nick.len > 0 { chalk.cyan(nick) } else { '' }

  // ================= PRIVMSG =================
  if command == 'PRIVMSG' {
    // CTCP ACTION
    if trailing.starts_with('\x01ACTION ') && trailing.ends_with('\x01') {
      action_text := trailing[8..trailing.len - 1]
      return '* ${chalk.bold(cnick)} ${action_text}'
    }
    return '<${cnick}> ${trailing}'
  }

  // ================= NOTICE =================
  if command == 'NOTICE' {
    if nick.len > 0 {
      return '-${cnick}- ${trailing}'
    }
    return '-!- ${trailing}'
  }

  // ================= JOIN =================
  if command == 'JOIN' {
    return '-!- ${cnick} has joined ${if trailing.len > 0 { trailing } else {target} }'
  }

  // ================= PART =================
  if command == 'PART' {
    if trailing.len > 0 {
      return '-!- ${cnick} has left ${target} (${trailing})'
    }
    return '-!- ${cnick} has left ${target}'
  }

  // ================= QUIT =================
  if command == 'QUIT' {
    if trailing.len > 0 {
      return '-!- ${cnick} has quit (${trailing})'
    }
    return '-!- ${cnick} has quit'
  }

  // ================= NICK =================
  if command == 'NICK' {
    newnick := if trailing.len > 0 { trailing } else { target }
    return '-!- ${cnick} is now known as ${chalk.cyan(newnick)}'
  }

  // ================= KICK =================
  if command == 'KICK' {
    parts := line.split(' ')
    if parts.len >= 4 {
      victim := parts[3]
      mut msg := '-!- ${cnick} kicked ${chalk.cyan(victim)} from ${chalk.cyan(target)}'
      if trailing.len > 0 {
        msg += ' (${trailing})'
      }
      return msg
    }
  }

  // ================= NUMERICS =================
  if command.len == 3 && command[0].is_digit() {
    if trailing.len > 0 {
      return '-!- ${trailing}'
    }
    return ''
  }

  // ================= FALLBACK =================
  if trailing.len > 0 {
    return '-!- ${command} ${trailing}'
  }

  return ''
}
