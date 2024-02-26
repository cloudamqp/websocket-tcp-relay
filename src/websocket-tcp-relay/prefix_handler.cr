require "http/server/handler"

class PrefixHandler
  include HTTP::Handler

  def initialize(@prefix : String)
    raise "Prefix has to start and end with /" unless @prefix.starts_with?('/') && @prefix.ends_with?('/')
    @prefix = @prefix[..-2]
  end

  def call(context)
    if context.request.path.starts_with? @prefix
      context.request.path = context.request.path[@prefix.bytesize..]
      call_next(context)
    else
      context.response.status_code = 404
    end
  end
end
