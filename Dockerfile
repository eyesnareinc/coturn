# Use Debian as the base image
FROM debian:bookworm

# Update package lists and install coturn
RUN apt-get update && \
    apt-get install -y coturn && \
    rm -rf /var/lib/apt/lists/*

# Expose ports for TURN server
EXPOSE 3478 5349 49152-65535/udp

# Start Coturn server
CMD ["turnserver", "--log-file=stdout"]
