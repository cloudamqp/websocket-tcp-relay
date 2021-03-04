# WebSocket TCP Relay

WebSocket server that relay traffic to any TCP server. It also serves static files from `--webroot` directory.

## Installation

TODO: Write installation instructions here

## Usage

```
Usage: websocket-tcp-relay [arguments]
    -u URI, --upstream=URI           Upstream (eg. tcp://localhost:5672 or tls://127.0.0.1:5671)
    -b HOST, --bind=HOST             Address to bind to (default localhost)
    -p PORT, --port=PORT             Address to bind to (default 8080)
    --tls-cert=PATH                  TLS certificate + chain (default ./certs/fullchain.pem)
    --tls-key=PATH                   TLS certificate key (default ./certs/privkey.pem)
    -P, --proxy-protocol             If the upstream expects the PROXY protocol (default false)
    -w PATH, --webroot=PATH          Directory from which to serve static content (default ./webroot)
    -c PATH, --config=PATH           Config file
    -v, --version                    Display version number
    -h, --help                       Show this help
```

Example config file:

```ini
[main]
upstream = tcp://127.0.0.1:5672
bind = 0.0.0.0
port = 8080
tls-cert = /etc/ssl/certs/mycert.pem
tls-key = /etc/ssl/private/mykey.pem
proxy-protocol = true
webroot = /var/lib/wwwroot
```
