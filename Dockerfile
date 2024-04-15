# Use Alpine Linux as the base image
FROM alpine:3.14

# Set environment variables for Coturn version and architecture
ARG COTURN_VERSION=4.6.2
ARG COTURN_ARCH=amd64

# Install dependencies
RUN apk add --no-cache \
    libevent \
    openssl \
    c-ares \
    && rm -rf /var/cache/apk/*

# Download and extract Coturn binary
RUN wget -O /tmp/coturn.tar.gz https://github.com/coturn/coturn/releases/download/$COTURN_VERSION/turnserver-$COTURN_VERSION.$COTURN_ARCH.tar.gz \
    && tar -xzf /tmp/coturn.tar.gz -C /tmp \
    && cp /tmp/turnserver-$COTURN_VERSION.$COTURN_ARCH/bin/turnserver /usr/local/bin/ \
    && rm -rf /tmp/*

# Expose ports for TURN server
EXPOSE 3478/tcp 3478/udp 5349/tcp 5349/udp 49152-65535/udp

# Start Coturn server
CMD ["turnserver"]


