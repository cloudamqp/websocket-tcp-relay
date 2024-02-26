FROM 84codes/crystal:latest-alpine AS builder
WORKDIR /tmp
COPY shard.yml shard.lock ./
RUN shards install --production
COPY src/ src/
RUN shards build --production --release --no-debug

FROM alpine:latest
RUN apk add --no-cache libssl3 pcre2 libevent libgcc
COPY --from=builder /tmp/bin/* /usr/bin/
USER 2:2
EXPOSE 15670
ENTRYPOINT ["/usr/bin/websocket-tcp-relay", "--bind=0.0.0.0"]
