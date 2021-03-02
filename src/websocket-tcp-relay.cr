require "option_parser"
require "./websocket-tcp-relay/*"

module WebSocketTCPRelay
  def self.run
    bind_addr = "localhost"
    bind_port = ENV.fetch("PORT", "").to_i? || 8080
    webroot = "./webroot"
    tls_cert_path = nil
    tls_key_path = nil
    upstream_uri = nil
    proxy_protocol = false

    OptionParser.parse do |parser|
      parser.banner = "Usage: #{File.basename PROGRAM_NAME} [arguments]"
      parser.on("-b HOST", "--bind=HOST", "Address to bind to (default 0.0.0.0)") do |v|
        bind_addr = v
      end
      parser.on("-p PORT", "--port=PORT", "Address to bind to (default 8080)") do |v|
        bind_port = v.to_i? || abort "Invalid port number"
      end
      parser.on("--tls-cert=PATH", "TLS certificate chain (default none)") do |v|
        tls_cert_path = v
      end
      parser.on("--tls-key=PATH", "TLS certificate key (default none)") do |v|
        tls_key_path = v
      end
      parser.on("-u URI", "--upstream=URI", "Upstream (eg. tcp://localhost:5672 or tls://127.0.0.1:5671)") do |v|
        upstream_uri = URI.parse(v)
      end
      parser.on("-P", "--proxy-protocol", "If the upstream expected the PROXY protocol") do
        proxy_protocol = true
      end
      parser.on("-w PATH", "--webroot=PATH", "Directory from which to serve static content (default ./webroot)") do |v|
        Dir.exists?(v) || abort "Directory '#{v}' doesn't exists"
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

      address =
        if tls_cert_path && tls_key_path
          context = OpenSSL::SSL::Context::Server.new
          context.certificate_chain = tls_cert_path.not_nil!
          context.private_key = tls_key_path.not_nil!
          server.bind_tls bind_addr, bind_port, context
        else
          server.bind_tcp bind_addr, bind_port
        end
      puts "Listening: #{address}"
      puts "Upstream: #{u}"
      puts "PROXY protocol: #{proxy_protocol ? "enabled" : "disabled"}"
      server.listen
    else
      abort "An upstream is required, must specify the --upstream flag"
    end
  end
end

WebSocketTCPRelay.run
