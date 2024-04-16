# Use Debian as the base image
FROM debian:bookworm

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
        libevent-dev \
        libssl-dev \
        libmicrohttpd-dev \
        libmysqlclient-dev \
        libhiredis-dev \
        libsqlite3-dev \
        libpq-dev \
        build-essential \
        automake \
        autoconf \
        libtool \
        wget \
        git && \
    rm -rf /var/lib/apt/lists/*

# Clone the Coturn repository
RUN git clone --branch master --depth 1 https://github.com/coturn/coturn.git /coturn

# Build Coturn
WORKDIR /coturn
RUN ./configure && \
    make && \
    make install

# Expose ports for TURN server
EXPOSE 3478 5349 49152-65535/udp

# Start Coturn server
CMD ["turnserver", "--log-file=stdout"]


