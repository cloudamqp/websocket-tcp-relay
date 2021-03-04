require "http/server"

module WebSocketTCPRelay
  class WebSocketRelay
    def self.new(host : String, port : Int32, tls : Bool, proxy_protocol : Bool)
      ::HTTP::WebSocketHandler.new do |ws, ctx|
        req = ctx.request
        remote_addr = req.remote_address.as(Socket::IPAddress)
        local_addr = req.local_address.as(Socket::IPAddress)
        if fwd = req.headers["Forwarded"]?
          if match = /^[Ff]or=(([\d.]+)|\[([\d:.A-Fa-f]+)\])(:(\d{1,5}))?[;,]?/.match(fwd)
            ip = match[2] || match[3]
            port = match[5].try(&.to_i) || 0
            remote_addr = Socket::IPAddress.new(ip, port)
          else
            puts "Invalid Forwarded header: '#{fwd}'"
          end
        elsif xfwd = req.headers["X-Forwarded-For"]?
          ip = (idx = xfwd.index(',')) ? xfwd[0, idx] : xfwd
          port = 0
          if xport = req.headers["X-Forwarded-Port"]?
            port = xport.to_i
          end
          remote_addr = Socket::IPAddress.new(ip, port)
        elsif realip = req.headers["X-Real-IP"]?
          remote_addr = Socket::IPAddress.new(realip, 0)
        end
        puts "#{remote_addr} connected"
        tcp_socket = TCPSocket.new(host, port, dns_timeout: 5, connect_timeout: 15)
        tcp_socket.tcp_nodelay = true
        tcp_socket.sync = true
        tcp_socket.read_buffering = false
        socket =
          if tls
            OpenSSL::SSL::Socket::Client.new(tcp_socket, hostname: host).tap do |c|
              c.sync_close = true
              c.sync = true
              c.read_buffering = false
            end
          else
            tcp_socket
          end
        if proxy_protocol
          tcp_v = remote_addr.@family == Socket::Family::INET6 ? "TCP6" : "TCP4"
          proxy = "PROXY #{tcp_v} #{remote_addr.address} #{local_addr.address} #{remote_addr.port} #{local_addr.port}\r\n"
          socket.write proxy.to_slice
        end

        ws.on_binary do |bytes|
          socket.write(bytes)
        end

        ws.on_close do |_code, _message|
          socket.close
        end

        spawn(name: "WS #{remote_addr}") do
          begin
            count = 0
            buffer = Bytes.new(4096)
            while (count = socket.read(buffer)) > 0
              ws.send(buffer[0, count])
            end
            puts "#{remote_addr} disconnected by server"
          rescue ex
            puts "#{remote_addr} disconnected: #{ex.inspect}"
          ensure
            ws.close rescue nil
            socket.close rescue nil
          end
        end
        puts "#{remote_addr} connected to upstream"
      rescue ex
        puts "#{remote_addr} disconnected: #{ex.inspect}"
        socket.try(&.close) rescue nil
        ws.close rescue nil
      end
    end
  end
end
