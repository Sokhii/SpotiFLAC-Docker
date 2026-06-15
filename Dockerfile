# ==========================================
# Stage 1: The Builder (Compiles the Source)
# ==========================================
FROM golang:1.26-bookworm AS builder

ARG SPOTIFLAC_VERSION=v7.1.6

# Corrected dependency installation logic
RUN apt-get update && apt-get install -y \
    curl \
    git \
    libgtk-3-dev \
    libwebkit2gtk-4.1-dev \
    libglib2.0-dev \
    libnss3-dev \
    libdbus-1-dev \
    build-essential \
    pkg-config \
    && (apt-get install -y libasound2-dev || apt-get install -y libasound2t64-dev) \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pnpm

RUN go install github.com/wailsapp/wails/v2/cmd/wails@latest
ENV PATH="/root/go/bin:${PATH}"

WORKDIR /build

RUN git clone https://github.com/afkarxyz/SpotiFLAC.git . && \
    (git checkout ${SPOTIFLAC_VERSION} || (echo "Tag ${SPOTIFLAC_VERSION} not found, falling back to main branch..." && git checkout main))

RUN wails build -platform linux/amd64 -clean -o SpotiFLAC -tags webkit2_41 -ldflags "-s -w"

# ==========================================
# Stage 2: The Runtime (The Efficient Container)
# ==========================================
FROM jlesage/baseimage-gui:debian-12-v4

ENV APP_NAME="SpotiFLAC"

RUN add-pkg \
    ffmpeg \
    libwebkit2gtk-4.1-0 \
    libgtk-3-0 \
    libnss3 \
    dbus-x11 \
    && (add-pkg libasound2 || add-pkg libasound2t64)

WORKDIR /app

COPY --from=builder /build/build/bin/SpotiFLAC /app/SpotiFLAC
RUN chmod +x /app/SpotiFLAC

# Corrected shell formatting for multi-line scripts
RUN printf "#!/bin/sh\n/app/SpotiFLAC\n" > /startapp.sh && \
    chmod +x /startapp.sh

ENV HOME=/config
