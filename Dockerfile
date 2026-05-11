# syntax=docker/dockerfile:1

FROM alpine:3.22

LABEL org.opencontainers.image.title="truenas-ncdu"
LABEL org.opencontainers.image.description="Run ncdu safely against TrueNAS SCALE datasets from a container."
LABEL org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache ncdu tini tmux ttyd

COPY entrypoint.sh /usr/local/bin/truenas-ncdu

ENV NCDU_PATH=/mnt
ENV NCDU_ONE_FILESYSTEM=true
ENV TERM=xterm-256color
ENV TRUENAS_NCDU_VERSION=0.2.1
ENV TTYD_PORT=7681
ENV TTYD_USER=admin

WORKDIR /mnt

USER root

EXPOSE 7681

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/truenas-ncdu"]
CMD ["web"]
