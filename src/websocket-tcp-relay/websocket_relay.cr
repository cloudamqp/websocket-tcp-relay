require "http/server"
require "openssl"
require "amq-protocol"

module WebSocketTCPRelay
  class WebSocketRelay
    def self.new(host : String, port : Int32, tls : Bool, proxy_protocol : Bool)
      tls_ctx = OpenSSL::SSL::Context::Client.new if tls
      ::HTTP::WebSocketHandler.new do |ws, ctx|
        req = ctx.request
        local_addr = req.local_address.as(Socket::IPAddress)
        remote_addr = remote_address(req.headers) || req.remote_address.as(Socket::IPAddress)
        puts "#{remote_addr} connected"
        tcp_socket = TCPSocket.new(host, port, dns_timeout: 5, connect_timeout: 15)
        tcp_socket.tcp_nodelay = true
        tcp_socket.read_buffering = false
        socket =
          if ctx = tls_ctx
            OpenSSL::SSL::Socket::Client.new(tcp_socket, ctx, hostname: host).tap do |c|
              c.sync_close = true
              c.read_buffering = false
            end
          else
            tcp_socket
          end
        if proxy_protocol
          if remote_addr.@family.inet6? || local_addr.@family.inet6?
            socket << "PROXY TCP6 "
            socket << "::ffff:" if remote_addr.@family.inet?
            socket << remote_addr.address << " "
            socket << "::ffff:" if local_addr.@family.inet?
            socket << local_addr.address << " "
          else
            socket << "PROXY TCP4 " << remote_addr.address << " " << local_addr.address << " "
          end
          socket << remote_addr.port << " " << local_addr.port << "\r\n"
          socket.flush
        end
        socket.as?(TCPSocket).try &.sync = true
        socket.as?(OpenSSL::SSL::Socket::Client).try &.sync = true

        ws.on_close do |_code, _message|
          socket.close
        end

        amqp_protocol = Channel(Bool).new
        first_bytes = true
        ws.on_binary do |bytes|
          if first_bytes
            first_bytes = false
            if bytes == AMQ::Protocol::PROTOCOL_START_0_9_1
              amqp_protocol.send true
            else
              amqp_protocol.send false
            end
          end
          socket.write(bytes)
        end
        spawn(name: "WS #{remote_addr}") do
          begin
            if amqp_protocol.receive
              mem = IO::Memory.new(4096)
              loop do
                frame = AMQ::Protocol::Frame.from_io(socket)
                frame.to_io(mem, IO::ByteFormat::NetworkEndian)
                ws.send(mem.to_slice)
                mem.clear
              end
            else
              buffer = Bytes.new(4096)
              count = 0
              while (count = socket.read(buffer)) > 0
                ws.send(buffer[0, count])
              end
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

    def self.remote_address(headers)
      if fwd = headers["Forwarded"]?
        if match = /^[Ff]or=(([\d.]+)|\[([\d:.A-Fa-f]+)\])(:(\d{1,5}))?[;,]?/.match(fwd)
          ip = match[2] || match[3]
          port = match[5].try(&.to_i) || 0
          Socket::IPAddress.new(ip, port)
        else
          puts "Invalid Forwarded header: '#{fwd}'"
        end
      elsif xfwd = headers["X-Forwarded-For"]?
        ip = (idx = xfwd.index(',')) ? xfwd[0, idx] : xfwd
        port = 0
        if xport = headers["X-Forwarded-Port"]?
          port = xport.to_i
        end
        Socket::IPAddress.new(ip, port)
      elsif ip = headers["X-Real-IP"]?
        Socket::IPAddress.new(ip, 0)
      end
    end
  end
end
