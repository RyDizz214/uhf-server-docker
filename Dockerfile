FROM ubuntu:25.04

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required dependencies
RUN apt-get update -o Acquire::Check-Valid-Until=false \
    && apt-get install -y --no-install-recommends \
        ca-certificates git curl bash unzip ffmpeg \
        build-essential autoconf automake libtool \
        libargtable2-dev pkg-config libsdl2-dev \
        libavcodec-dev libavformat-dev libavfilter-dev libavutil-dev \
        libavdevice-dev libjansson-dev \
    && rm -rf /var/lib/apt/lists/*

# Create directory for recordings
RUN mkdir -p /recordings

# Create directory for db
RUN mkdir -p /var/lib/uhf-server

# Set working directory
WORKDIR /app

# Install UHF server 
RUN curl -sL https://link.uhfapp.com/setup.sh > setup.sh && \
    chmod +x setup.sh && \
    bash setup.sh && \
    rm setup.sh

# Expose default port
EXPOSE ${PORT}

# Default command
CMD ["bash"]