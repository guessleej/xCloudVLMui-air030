FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    gstreamer1.0-libav \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-rtsp \
    gstreamer1.0-tools \
    v4l-utils \
    && rm -rf /var/lib/apt/lists/*

COPY start-d435i-rtsp.sh /usr/local/bin/start-d435i-rtsp.sh
RUN chmod +x /usr/local/bin/start-d435i-rtsp.sh

CMD ["/usr/local/bin/start-d435i-rtsp.sh"]
