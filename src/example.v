module main

import vircc

fn main()
{
  // Connect to the IRC server
  mut conn := irc.connect("chat.frothy7650.org", "6667")

  // Handle until exits
  conn.handle()!
}
