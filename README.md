## IRC
Simple IRC library.


## Usage
Here is a minimal example of how do use vircc
```
import frothy7650.vircc
import os

fn main()
{
  ip := os.input("IP: ")
  nick := os.input("Nick: ")

  mut conn := vircc.connect(ip, "6667", nick)
  conn.color = true
  conn.login()!

  // --- receiving messages ---
  // I don't know if there is a better way
  // to do this, so i recommend running it
  // in the background like this

  go fn [mut conn]() {
    for conn.is_running {
      line := conn.readline() or { continue }
      println(line)
    }
  }()

  // --- sending messages ---
  // To send messages, run conn.writeline()
  // and handle the errors, you don't have
  // to loop it like i did, just run it whenever
  for conn.is_running {
    input := os.input("")
    conn.writeline(input) or { eprintln("Write error") continue }
  }
}
```
