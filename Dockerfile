# Use Ubuntu as the base image
FROM debian:latest

# Update packages and install coturn
RUN apt-get update && apt-get install -y coturn

# Expose the necessary ports
# These are the default ports coturn uses, but you may need to adjust them according to your setup
EXPOSE 3478 3478/udp 5349 5349/udp 49152-65535/udp

# Command to run coturn
CMD ["turnserver", "--log-file", "stdout"]
