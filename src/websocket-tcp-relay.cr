require "option_parser"
require "./websocket-tcp-relay/*"

module WebSocketTCPRelay
  def self.run
    bind_addr = "localhost"
    bind_port = ENV.fetch("PORT", "").to_i? || 8080
    webroot = "./webroot"
    tls_cert_path = "./certs/fullchain.pem"
    tls_key_path = "./certs/privkey.pem"
    upstream_uri = nil
    proxy_protocol = false

    OptionParser.parse do |parser|
      parser.banner = "Usage: #{File.basename PROGRAM_NAME} [arguments]"
      parser.on("-u URI", "--upstream=URI", "Upstream (eg. tcp://localhost:5672 or tls://127.0.0.1:5671)") do |v|
        upstream_uri = URI.parse(v)
      end
      parser.on("-b HOST", "--bind=HOST", "Address to bind to (default #{bind_addr})") do |v|
        bind_addr = v
      end
      parser.on("-p PORT", "--port=PORT", "Address to bind to (default #{bind_port})") do |v|
        bind_port = v.to_i? || abort "Invalid port number"
      end
      parser.on("--tls-cert=PATH", "TLS certificate + chain (default #{tls_cert_path})") do |v|
        tls_cert_path = v
      end
      parser.on("--tls-key=PATH", "TLS certificate key (default #{tls_key_path})") do |v|
        tls_key_path = v
      end
      parser.on("-P", "--proxy-protocol", "If the upstream expects the PROXY protocol (default #{proxy_protocol})") do
        proxy_protocol = true
      end
      parser.on("-w PATH", "--webroot=PATH", "Directory from which to serve static content (default #{webroot})") do |v|
        webroot = v
      end
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit
      end
      parser.invalid_option do |flag|
        STDERR.puts "ERROR: #{flag} is not a valid option."
        STDERR.puts parser
        exit 1
      end
    end

    if u = upstream_uri
      MIME.register(".mjs", "text/javascript;charset=utf-8") # ecmascript modules

      server = HTTP::Server.new([
        WebSocketRelay.new(u.host || "127.0.0.1", u.port || 5672, u.scheme == "tls", proxy_protocol),
        HTTP::StaticFileHandler.new(webroot, fallthrough: false, directory_listing: false)
      ])

      address = nil
      protocol = "http"
      if File.exists?(tls_cert_path) && File.exists?(tls_key_path)
        context = OpenSSL::SSL::Context::Server.new
        context.certificate_chain = tls_cert_path
        context.private_key = tls_key_path
        address = server.bind_tls bind_addr, bind_port, context
        protocol = "https"
      else
        address = server.bind_tcp bind_addr, bind_port
      end
      puts "Listening: #{protocol}://#{address}"
      puts "Upstream: #{u}"
      puts "PROXY protocol: #{proxy_protocol ? "enabled" : "disabled"}"
      puts "Web root: #{Dir.exists?(webroot) ? File.expand_path webroot : "Not found"}"
      server.listen
    else
      abort "An upstream is required, must specify the --upstream flag"
    end
  end
end

WebSocketTCPRelay.run
