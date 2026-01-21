require "http/server/handler"

module WebSocketTCPRelay
  class WebSocketProtocolHandler
    include HTTP::Handler

    def initialize(@protocols : Enumerable(String))
    end

    def call(context)
      handle_sub_protocol(context)
      call_next(context)
    end

    private def handle_sub_protocol(ctx)
      valid_protocols = @protocols
      return if valid_protocols.empty?
      if protocols = ctx.request.headers.get?("Sec-WebSocket-Protocol")
        if protocol = protocols.find { |p| valid_protocols.any? &.== p }
          ctx.response.headers["Sec-WebSocket-Protocol"] = protocol
        end
      end
    end
  end
end
