FROM ubuntu:25.04

# Silence prompts
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install runtime + build deps (including libargtable2-0 + libargtable2-dev)
RUN apt-get update --allow-releaseinfo-change || true && \
    apt-get install -y --no-install-recommends --fix-missing \
      curl \
      ffmpeg \
      unzip \
      ca-certificates \
      git \
      build-essential \
      autoconf \
      automake \
      pkg-config \
      libargtable2-0 \
      libargtable2-dev \
      libavformat-dev \
      libavcodec-dev \
      libavutil-dev \
      libswscale-dev \
      libsdl1.2-dev \
      libsdl2-dev \
      libtool \
    && rm -rf /var/lib/apt/lists/*

# 2. Clone, compile, and install Comskip
RUN git clone https://github.com/erikkaashoek/Comskip /tmp/Comskip && \
    cd /tmp/Comskip && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install && \
    rm -rf /tmp/Comskip

# 3. Purge build-only packages (keep libargtable2-0 for runtime)
RUN apt-get purge -y \
      git \
      build-essential \
      autoconf \
      automake \
      pkg-config \
      libargtable2-dev \
      libavformat-dev \
      libavcodec-dev \
      libavutil-dev \
      libswscale-dev \
      libsdl1.2-dev \
      libsdl2-dev \
      libtool \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 4. Create necessary directories
RUN mkdir -p /recordings /var/lib/uhf-server

WORKDIR /app

# 5. Install UHF Server
RUN curl -sL https://link.uhfapp.com/setup.sh > setup.sh && \
    chmod +x setup.sh && \
    bash setup.sh && \
    rm setup.sh

# 6. Expose the port (UHF listens on 8000 by default)
EXPOSE 8000

# 7. Healthcheck
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/server/stats || exit 1

# 8. Default command
CMD ["bash"]
