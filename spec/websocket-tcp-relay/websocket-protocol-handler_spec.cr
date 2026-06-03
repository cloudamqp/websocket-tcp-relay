require "http"
require "../spec_helper"

def with_relay(protocols : Enumerable(String) = Iterator(String).empty, **kwargs, &)
  TCPServer.open(0) do |us| # start an upstream to get rid of errors
    relay_args = {
      host:           us.local_address.address,
      port:           us.local_address.port,
      tls:            false,
      proxy_protocol: false,
    }.merge(kwargs)
    protocol_handler = WebSocketTCPRelay::WebSocketProtocolHandler.new(protocols)
    TCPServer.open(0) do |server|
      http = HTTP::Server.new({protocol_handler}) do |ctx|
        ctx.response.status = HTTP::Status::NO_CONTENT
      end
      http.bind server
      spawn { http.listen }
      Fiber.yield
      TCPSocket.open(server.local_address.address, server.local_address.port) do |socket|
        yield socket
      end
    ensure
      http.try &.close
    end
  end
end

describe WebSocketTCPRelay::WebSocketProtocolHandler do
  describe "Sec-WebSocket-Protocol" do
    it "should not be set if no protocol configured" do
      with_relay do |socket|
        handshake = HTTP::Request.new("GET", "/")
        handshake.to_io(socket)
        handshake_response = HTTP::Client::Response.from_io(socket, ignore_body: true)
        response_headers = handshake_response.headers
        response_headers.has_key?("Sec-WebSocket-Protocol").should be_false
      end
    end

    it "should be set if requested value is configured" do
      with_relay(protocols: {"amqp"}) do |socket|
        headers : HTTP::Headers = HTTP::Headers.new
        headers["Sec-WebSocket-Protocol"] = "amqp"

        handshake = HTTP::Request.new("GET", "/", headers)
        handshake.to_io(socket)
        handshake_response = HTTP::Client::Response.from_io(socket, ignore_body: true)
        response_headers = handshake_response.headers
        response_headers.has_key?("Sec-WebSocket-Protocol").should be_true
        response_headers["Sec-WebSocket-Protocol"].should eq "amqp"
      end
    end

    it "should be set if requested value is one of many configured" do
      with_relay(protocols: {"mqtt", "amqp", "smtp"}) do |socket|
        headers : HTTP::Headers = HTTP::Headers.new
        headers["Sec-WebSocket-Protocol"] = "amqp"

        handshake = HTTP::Request.new("GET", "/", headers)
        handshake.to_io(socket)
        handshake_response = HTTP::Client::Response.from_io(socket, ignore_body: true)
        response_headers = handshake_response.headers
        response_headers.has_key?("Sec-WebSocket-Protocol").should be_true
        response_headers["Sec-WebSocket-Protocol"].should eq "amqp"
      end
    end

    it "should not be set if requested value is not configured" do
      with_relay(protocols: {"amqp"}) do |socket|
        headers : HTTP::Headers = HTTP::Headers.new
        headers["Sec-WebSocket-Protocol"] = "mqtt"

        handshake = HTTP::Request.new("GET", "/", headers)
        handshake.to_io(socket)
        handshake_response = HTTP::Client::Response.from_io(socket, ignore_body: true)
        response_headers = handshake_response.headers
        response_headers.has_key?("Sec-WebSocket-Protocol").should be_false
      end
    end
  end
end
