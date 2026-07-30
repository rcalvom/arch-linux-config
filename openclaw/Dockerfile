# syntax=docker/dockerfile:1

# Match OpenClaw's documented minimal Docker sandbox image with a reviewed digest.
FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818 AS base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    python3 \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash sandbox

USER sandbox
WORKDIR /home/sandbox
CMD ["sleep", "infinity"]

# Repository agents need SSH for Git remotes. Do not bake keys into this image.
FROM base AS ssh

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

USER sandbox
WORKDIR /home/sandbox
CMD ["sleep", "infinity"]
