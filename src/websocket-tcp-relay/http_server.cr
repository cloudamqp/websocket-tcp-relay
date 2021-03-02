require "http/server"
require "socket/address"

# Backporting HTTP::Request#local_address for Crystal 0.36.1
# Merged in later versions: https://github.com/crystal-lang/crystal/pull/10385
class HTTP::Request
  property local_address : Socket::Address?

  def self.from_io(io, *, max_request_line_size : Int32 = HTTP::MAX_REQUEST_LINE_SIZE, max_headers_size : Int32 = HTTP::MAX_HEADERS_SIZE) : HTTP::Request | HTTP::Status | Nil
    line = parse_request_line(io, max_request_line_size)
    return line unless line.is_a?(RequestLine)
    status = HTTP.parse_headers_and_body(io, max_headers_size: max_headers_size) do |headers, body|
      request = new line.method, line.resource, headers, body, line.http_version, internal: nil
      if io.responds_to?(:remote_address)
        request.remote_address = io.remote_address
      end
      if io.responds_to?(:local_address)
        request.local_address = io.local_address
      end
      return request
    end
    status || HTTP::Status::BAD_REQUEST
  end
end
