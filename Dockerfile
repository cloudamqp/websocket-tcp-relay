FROM 84codes/crystal:1.3.2-alpine-latest AS builder

WORKDIR /tmp
COPY shard.yml shard.lock ./
RUN shards install --production
COPY src/ src/
RUN shards build --release --production --static --no-debug

FROM alpine:latest
USER 2:2
COPY --from=builder /tmp/bin/* /usr/local/bin/
EXPOSE 15670
ENTRYPOINT ["/usr/local/bin/websocket-tcp-relay", "--bind", "0.0.0.0"]
