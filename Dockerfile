# Use a base image with necessary dependencies
FROM debian:bullseye AS builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y git build-essential libevent-dev libssl-dev

# Clone Coturn repository
RUN git clone https://github.com/coturn/coturn.git /coturn-src

# Build Coturn
RUN cd /coturn-src && \
    ./configure && \
    make

# Start with a fresh image for the final Coturn image
FROM debian:bullseye

# Copy Coturn binaries from builder stage
COPY --from=builder /coturn-src/bin/turnserver /usr/local/bin/turnserver

# Copy configuration files, etc.
COPY turnserver.conf /etc/turnserver.conf

# Expose ports for Coturn
EXPOSE 3478
EXPOSE 5349
EXPOSE 49152-65535/udp

# Set the entrypoint command
ENTRYPOINT ["turnserver", "-c", "/etc/turnserver.conf"]

