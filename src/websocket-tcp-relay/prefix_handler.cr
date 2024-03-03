require "http/server/handler"

class PrefixHandler
  include HTTP::Handler

  def initialize(prefix : String)
    @prefix = "/#{prefix.strip('/')}/"
  end

  def call(context)
    if @prefix == "//"
      call_next(context)
    elsif context.request.path.starts_with? @prefix
      context.request.path = context.request.path[@prefix.bytesize - 1..]
      call_next(context)
    else
      context.response.respond_with_status(404)
    end
  end
end
