#
# Dockerfile of coturn/coturn:debian Docker image.
#

ARG debian_ver=bookworm




#
# Stage 'dist-libprom' creates prometheus-client-c distribution.
#

# We compile prometheus-client-c from sources, because Debian doesn't provide
# it as its package yet.
#
# TODO: Re-check this to be present in packages on next Debian major version update.

# https://hub.docker.com/_/debian
FROM debian:${debian_ver}-slim AS dist-libprom

# Install tools for building.
RUN apt-get update \
 && apt-get install -y --no-install-recommends --no-install-suggests \
            ca-certificates cmake g++ git make \
 && update-ca-certificates

# Install prometheus-client-c build dependencies.
RUN apt-get install -y --no-install-recommends --no-install-suggests \
            libmicrohttpd-dev

# Prepare prometheus-client-c sources for building.
ARG prom_ver=0.1.3
RUN mkdir -p /build/ && cd /build/ \
 && git init \
 && git remote add origin https://github.com/digitalocean/prometheus-client-c \
 && git fetch --depth=1 origin "v${prom_ver}" \
 && git checkout FETCH_HEAD

# Build libprom.so from sources.
RUN mkdir -p /build/prom/build/ && cd /build/prom/build/ \
 && TEST=0 cmake -G "Unix Makefiles" \
                 -DCMAKE_INSTALL_PREFIX=/usr \
                 -DCMAKE_SKIP_BUILD_RPATH=TRUE \
                 -DCMAKE_C_FLAGS="-DPROM_LOG_ENABLE -g -O3" \
                 .. \
 && make

# Build libpromhttp.so from sources.
RUN mkdir -p /build/promhttp/build/ && cd /build/promhttp/build/ \
 # Fix compiler warning: -Werror=incompatible-pointer-types
 && sed -i 's/\&promhttp_handler/(MHD_AccessHandlerCallback)\&promhttp_handler/' \
           /build/promhttp/src/promhttp.c \
 && TEST=0 cmake -G "Unix Makefiles" \
                 -DCMAKE_INSTALL_PREFIX=/usr \
                 -DCMAKE_SKIP_BUILD_RPATH=TRUE \
                 -DCMAKE_C_FLAGS="-g -O3" \
                 .. \
 && make VERBOSE=1

# Install prometheus-client-c.
RUN LIBS_DIR=/out/$(dirname $(find /usr/ -name libc.so)) \
 && mkdir -p $LIBS_DIR/ \
 && cp -rf /build/prom/build/libprom.so \
           /build/promhttp/build/libpromhttp.so \
       $LIBS_DIR/ \
 && mkdir -p /out/usr/include/ \
 && cp -rf /build/prom/include/* \
           /build/promhttp/include/* \
       /out/usr/include/ \
 # Preserve license file.
 && mkdir -p /out/usr/share/licenses/prometheus-client-c/ \
 && cp /build/LICENSE /out/usr/share/licenses/prometheus-client-c/




#
# Stage 'dist-coturn' creates Coturn distribution.
#

# https://hub.docker.com/_/debian
FROM debian:${debian_ver}-slim AS dist-coturn

# Install tools for building.
RUN apt-get update \
 && apt-get install -y --no-install-recommends --no-install-suggests \
            autoconf ca-certificates coreutils g++ git libtool make pkg-config \
 && update-ca-certificates

# Install Coturn build dependencies.
RUN apt-get install -y --no-install-recommends --no-install-suggests \
            libevent-dev \
            libssl-dev \
            libpq-dev libmariadb-dev libsqlite3-dev \
            libhiredis-dev \
            libmongoc-dev \
            libmicrohttpd-dev

# Install prometheus-client-c distribution.
COPY --from=dist-libprom /out/ /

# Prepare local Coturn sources for building.
COPY CMakeLists.txt \
     configure \
     INSTALL \
     LICENSE \
     make-man.sh Makefile.in \
     postinstall.txt \
     README.turn* \
     /app/
COPY cmake/ /app/cmake/
COPY examples/ /app/examples/
COPY man/ /app/man/
COPY src/ /app/src/
COPY turndb/ /app/turndb/
WORKDIR /app/

# Use Coturn sources from Git if `coturn_git_ref` is specified.
ARG coturn_git_ref=HEAD
ARG coturn_github_url=https://github.com
ARG coturn_github_repo=coturn/coturn

RUN if [ "${coturn_git_ref}" != 'HEAD' ]; then true \
 && rm -rf /app/* \
 && git init \
 && git remote add origin ${coturn_github_url}/${coturn_github_repo} \
 && git fetch --depth=1 origin "${coturn_git_ref}" \
 && git checkout FETCH_HEAD \
 && true; fi

# Build Coturn from sources.
RUN ./configure --prefix=/usr \
                --turndbdir=/var/lib/coturn \
                --disable-rpath \
                --sysconfdir=/etc/coturn \
                # No documentation included to keep image size smaller.
                --mandir=/tmp/coturn/man \
                --docsdir=/tmp/coturn/docs \
                --examplesdir=/tmp/coturn/examples \
 && make

# Install and configure Coturn.
RUN mkdir -p /out/ \
 && DESTDIR=/out make install \
 # Remove redundant files.
 && rm -rf /out/tmp/ \
 # Preserve license file.
 && mkdir -p /out/usr/share/licenses/coturn/ \
 && cp LICENSE /out/usr/share/licenses/coturn/ \
 # Remove default config file.
 && rm -f /out/etc/coturn/turnserver.conf.default

# Install helper tools of Docker image.
COPY docker/coturn/rootfs/ /out/
RUN chmod +x /out/usr/local/bin/docker-entrypoint.sh \
             /out/usr/local/bin/detect-external-ip.sh
RUN ln -s /usr/local/bin/detect-external-ip.sh \
          /out/usr/local/bin/detect-external-ip
RUN chown -R nobody:nogroup /out/var/lib/coturn/

# Re-export prometheus-client-c distribution.
COPY --from=dist-libprom /out/ /out/

