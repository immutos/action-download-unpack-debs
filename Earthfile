VERSION 0.8

all:
  ARG VERSION=dev
  BUILD --platform=linux/amd64 --platform=linux/arm64 +docker-bookworm
  BUILD --platform=linux/amd64 --platform=linux/arm64 --platform=linux/riscv64 +docker-trixie

lint:
  FROM koalaman/shellcheck-alpine:v0.10.0
  WORKDIR /workspace
  COPY ./*.sh ./
  RUN shellcheck *.sh

docker-bookworm:
  FROM debian:bookworm-slim
  RUN apt update \
    && apt install -y fakechroot \
    && rm -rf /var/lib/apt/lists/*
  COPY LICENSE /usr/share/doc/action-download-unpack-debs/copyright
  COPY download-unpack-debs.sh /usr/local/bin/download-unpack-debs.sh
  RUN chmod +x /usr/local/bin/download-unpack-debs.sh
  ENTRYPOINT ["/usr/local/bin/download-unpack-debs.sh"]
  ARG VERSION=dev
  SAVE IMAGE --push ghcr.io/immutos/action-download-unpack-debs:${VERSION}-bookworm
  SAVE IMAGE --push ghcr.io/immutos/action-download-unpack-debs:bookworm

docker-trixie:
  FROM debian:trixie-slim
  RUN apt update \
    && apt install -y fakechroot \
    && rm -rf /var/lib/apt/lists/*
  COPY LICENSE /usr/share/doc/action-download-unpack-debs/copyright
  COPY download-unpack-debs.sh /usr/local/bin/download-unpack-debs.sh
  RUN chmod +x /usr/local/bin/download-unpack-debs.sh
  ENTRYPOINT ["/usr/local/bin/download-unpack-debs.sh"]
  ARG VERSION=dev
  SAVE IMAGE --push ghcr.io/immutos/action-download-unpack-debs:${VERSION}-trixie
  SAVE IMAGE --push ghcr.io/immutos/action-download-unpack-debs:trixie