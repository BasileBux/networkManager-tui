# NetworkManager TUI

> [!WARNING]
> This is still far from finished and has absolutely no functionality whatsoever. Please consider
> waiting a bit, and it will eventually be released.

The existing [NetworkManager TUI](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/networking_guide/sec-configuring_ip_networking_with_nmtui)
is, in my opinion, quite unattractive, and I really don't enjoy using it. That's why I am writing a new, modern
version. It is primarily a pretext to learn [Zig](https://ziglang.org/), but I also want to create
a nice TUI to connect to Wi-Fi networks and manage network connections.

## Features

- Connect / Add Wi-Fi (basic and WPA2 (eduroam))
- Disconnect / Remove Wi-Fi
- Scan local networks

## How to Run

- You need [Zig](https://ziglang.org/) installed, and that's all. 
- Then clone this repository and navigate into it. Just run `zig build`, and you will find an executable
under `./zig-out/bin/networkManager-tui`.

