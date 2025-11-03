########################################
# Build Configuration
# These are baked into the image at build time with defaults
########################################

########################################
# Stage 1: Build FFmpeg from source
########################################
FROM ubuntu:25.04 AS ffmpeg-build

ARG DEBIAN_FRONTEND=noninteractive
ARG FFMPEG_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates wget unzip xz-utils grep coreutils \
    build-essential pkg-config autoconf automake cmake libtool \
    yasm nasm meson ninja-build \
    libfreetype6-dev libass-dev libfontconfig1-dev libunistring-dev libnuma-dev \
    libfribidi-dev libharfbuzz-dev \
    libssl-dev \
    libx11-dev libxext-dev libxfixes-dev libxi-dev libxrender-dev libxrandr-dev \
    && rm -rf /var/lib/apt/lists/*

# x264 (static)
RUN git clone --depth=1 https://code.videolan.org/videolan/x264.git /tmp/x264 \
    && cd /tmp/x264 \
    && ./configure --prefix=/usr/local --enable-static --enable-pic \
    && make -j"$(nproc)" && make install

# x265 (static) + pkg-config metadata
RUN git clone --depth=1 https://github.com/videolan/x265.git /tmp/x265 \
    && cd /tmp/x265/build/linux \
    && cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DENABLE_SHARED=OFF \
        ../../source \
    && make -j"$(nproc)" && make install \
    && mkdir -p /usr/local/lib/pkgconfig \
    && { \
        echo 'prefix=/usr/local'; \
        echo 'exec_prefix=${prefix}'; \
        echo 'libdir=${exec_prefix}/lib'; \
        echo 'includedir=${prefix}/include'; \
        echo ''; \
        echo 'Name: x265'; \
        echo 'Description: H.265/HEVC video encoder'; \
        echo 'Version: 3.5'; \
        echo 'Libs: -L${libdir} -lx265 -lstdc++ -lm -lpthread -ldl -lnuma'; \
        echo 'Cflags: -I${includedir}'; \
    } > /usr/local/lib/pkgconfig/x265.pc \
    && ldconfig

# fdk-aac (static)
RUN git clone --depth=1 https://github.com/mstorsjo/fdk-aac.git /tmp/fdk-aac \
    && cd /tmp/fdk-aac && autoreconf -fiv \
    && ./configure --prefix=/usr/local --disable-shared \
    && make -j"$(nproc)" && make install

# libvpx (static)
RUN git clone --depth=1 https://chromium.googlesource.com/webm/libvpx /tmp/libvpx \
    && cd /tmp/libvpx \
    && ./configure --prefix=/usr/local --disable-examples --disable-unit-tests --enable-vp9-highbitdepth \
    && make -j"$(nproc)" && make install

# opus (static)
RUN git clone --depth=1 https://github.com/xiph/opus.git /tmp/opus \
    && cd /tmp/opus && ./autogen.sh \
    && ./configure --prefix=/usr/local --disable-shared \
    && make -j"$(nproc)" && make install

# FFmpeg (latest stable or overridden via FFMPEG_VERSION)
RUN set -eux; \
    if [ "${FFMPEG_VERSION}" = "latest" ]; then \
        FFMPEG_TARBALL="$(curl -fsSL https://ffmpeg.org/releases/ | grep -Eo 'ffmpeg-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.xz' | grep -vE 'rc|git' | sort -V | tail -1)"; \
    else \
        FFMPEG_TARBALL="ffmpeg-${FFMPEG_VERSION}.tar.xz"; \
    fi; \
    echo "Selected FFmpeg: ${FFMPEG_TARBALL}"; \
    curl -fsSLo "/tmp/${FFMPEG_TARBALL}" "https://ffmpeg.org/releases/${FFMPEG_TARBALL}"; \
    mkdir -p /tmp/ffmpeg && tar -xf "/tmp/${FFMPEG_TARBALL}" -C /tmp/ffmpeg --strip-components=1; \
    cd /tmp/ffmpeg; \
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"; \
    ./configure \
        --prefix=/usr/local \
        --pkg-config-flags="--static" \
        --extra-cflags="-I/usr/local/include" \
        --extra-ldflags="-L/usr/local/lib" \
        --extra-libs="-lpthread -lm -ldl -lnuma" \
        --bindir=/usr/local/bin \
        --enable-gpl --enable-nonfree \
        --enable-openssl \
        --enable-libx264 --enable-libx265 --enable-libfdk_aac \
        --enable-libvpx --enable-libopus --enable-libass --enable-libfreetype \
        --disable-debug --disable-doc; \
    make -j"$(nproc)" && make install && hash -r

########################################
# Stage 2: Build Comskip from source
########################################
FROM ubuntu:25.04 AS comskip-build

ARG DEBIAN_FRONTEND=noninteractive
ARG COMSKIP_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates pkg-config \
    build-essential autoconf automake libtool \
    libargtable2-dev \
    libavformat-dev libavcodec-dev libavutil-dev libswscale-dev \
    libsdl1.2-dev libsdl2-dev \
    && rm -rf /var/lib/apt/lists/*

# Fetch and build Comskip at a stable release tag by default; fall back to master if lookup fails
RUN set -eux; \
    COMSKIP_REPO="https://github.com/erikkaashoek/Comskip"; \
    SELECTED_VERSION="${COMSKIP_VERSION}"; \
    if [ "${SELECTED_VERSION}" = "latest" ]; then \
        SELECTED_VERSION="$(curl -fsSL https://api.github.com/repos/erikkaashoek/Comskip/releases/latest \
            | grep -Eo '\"tag_name\"\\s*:\\s*\"[^\"]+\"' \
            | head -n1 \
            | sed -E 's/.*\"([^\"[:space:]]+)\"/\\1/')"; \
        if [ -z "${SELECTED_VERSION}" ]; then \
            echo "Unable to determine latest release tag; defaulting to master branch"; \
            SELECTED_VERSION="master"; \
        fi; \
    fi; \
    git clone --depth 1 --branch "${SELECTED_VERSION}" "${COMSKIP_REPO}" /tmp/Comskip; \
    cd /tmp/Comskip; \
    ./autogen.sh; \
    ./configure --prefix=/usr/local; \
    make -j"$(nproc)"; \
    make install

########################################
# Stage 3: Runtime
########################################
FROM ubuntu:25.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UHF_SERVER_VERSION=1.5.1
ARG UHF_SERVER_ARCH=linux-x64

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip tzdata \
    libargtable2-0 \
    libavformat61 libavcodec61 libavutil59 libswscale8 libswresample5 \
    libx11-6 libxext6 libxrender1 libxfixes3 libxi6 libxrandr2 \
    libnuma1 libstdc++6 libssl3 \
    libass9 libfreetype6 libfribidi0 libharfbuzz0b libfontconfig1 libpng16-16 \
    libsdl2-2.0-0 libsdl1.2debian libvdpau1 libvpl2 \
    ocl-icd-libopencl1 \
    dbus-user-session systemd \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /recordings /var/lib/uhf-server /app

WORKDIR /app

# Copy compiled FFmpeg binaries and libraries from stage 1
COPY --from=ffmpeg-build /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=ffmpeg-build /usr/local/bin/ffprobe /usr/local/bin/ffprobe
COPY --from=ffmpeg-build /usr/local/lib/libav*.so* /usr/local/lib/
COPY --from=ffmpeg-build /usr/local/lib/libswscale*.so* /usr/local/lib/
COPY --from=ffmpeg-build /usr/local/lib/libx264*.so* /usr/local/lib/
COPY --from=ffmpeg-build /usr/local/lib/libx265*.so* /usr/local/lib/
COPY --from=ffmpeg-build /usr/local/lib/libvpx*.so* /usr/local/lib/
COPY --from=ffmpeg-build /usr/local/lib/libopus*.so* /usr/local/lib/
COPY --from=ffmpeg-build /usr/local/lib/libfdk-aac*.so* /usr/local/lib/
RUN ln -sf /usr/local/bin/ffmpeg /usr/bin/ffmpeg && \
    ln -sf /usr/local/bin/ffprobe /usr/bin/ffprobe && \
    ldconfig

# Copy compiled Comskip from stage 2
COPY --from=comskip-build /usr/local/bin/comskip /usr/local/bin/comskip

# Rebuild ld cache
RUN ldconfig

# Download and install UHF Server
RUN set -eux; \
    APP_URL="https://github.com/swapplications/uhf-server-dist/releases/download/${UHF_SERVER_VERSION}/UHF.Server-${UHF_SERVER_ARCH}-${UHF_SERVER_VERSION}.zip"; \
    echo "Downloading UHF Server from: ${APP_URL}"; \
    curl -fsSL -o /tmp/uhf-server.zip "${APP_URL}"; \
    unzip -q /tmp/uhf-server.zip -d /app; \
    rm -f /tmp/uhf-server.zip; \
    find /app -maxdepth 2 -type f \( -name "*.sh" -o -name "uhf-server" -o -name "*.bin" \) -exec chmod +x {} + || true

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Image metadata
LABEL org.opencontainers.image.title="UHF Server" \
      org.opencontainers.image.description="UHF Server with FFmpeg and Comskip in Docker" \
      org.opencontainers.image.version="1.5.1" \
      org.opencontainers.image.source="https://github.com/rydizz214/uhf-server-docker" \
      org.opencontainers.image.url="https://github.com/rydizz214/uhf-server-docker"

# Default environment variables
ENV TZ=America/New_York \
    UHF_PORT=8000 \
    UHF_RECORDINGS_DIR=/recordings \
    UHF_DATA_DIR=/var/lib/uhf-server \
    UHF_ENABLE_COMMERCIAL_DETECTION=true \
    COMSKIP_ARGS=--ini

# Expose port
EXPOSE 8000

# Healthcheck
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${UHF_PORT}/server/stats || exit 1

# Entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
