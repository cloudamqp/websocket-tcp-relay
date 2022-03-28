# WebSocket TCP Relay

WebSocket server that relay traffic to any TCP server. It also serves static files from `--webroot` directory.

## Installation

Debian/Ubuntu:

```bash
wget -qO- https://packagecloud.io/cloudamqp/websocket-tcp-relay/gpgkey | sudo apt-key add -
echo "deb https://packagecloud.io/cloudamqp/websocket-tcp-relay/ubuntu/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/websocket-tcp-relay.list

sudo apt update
sudo apt install websocket-tcp-relay
```

Docker/Podman:

Docker images are published to [Docker Hub](https://hub.docker.com/r/cloudamqp/websocket-tcp-relay). Fetch and run the latest version with:

`docker run --rm -it -p 15670:15670 cloudamqp/websocket-tcp-relay --upstream tcp://container:5672`

## Usage

```
Usage: websocket-tcp-relay [arguments]
    -u URI, --upstream=URI           Upstream (eg. tcp://localhost:5672 or tls://127.0.0.1:5671)
    -b HOST, --bind=HOST             Address to bind to (default localhost)
    -p PORT, --port=PORT             Address to bind to (default 15670)
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
bind = 127.0.0.1
port = 15670
proxy-protocol = false
webroot = /var/lib/wwwroot
tls-cert = /etc/ssl/certs/fullchain.pem
tls-key = /etc/ssl/private/privkey.pem
```
