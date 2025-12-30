FROM python:3.11-slim

WORKDIR /app

# -----------------------------
# System dependencies
# -----------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      pulseaudio \
      pulseaudio-utils \
      snapclient \
      squeezelite \
      avahi-daemon \
      libnss-mdns \
      ca-certificates \
      build-essential \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Non-root user
# -----------------------------
RUN useradd --create-home --shell /bin/bash ledfx
USER ledfx
WORKDIR /home/ledfx

# -----------------------------
# Install latest LedFx
# -----------------------------
RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install ledfx

# -----------------------------
# PulseAudio config (null sink)
# -----------------------------
RUN mkdir -p /home/ledfx/.config/pulse /tmp/pulse

RUN printf "\
daemonize = no\n\
exit-idle-time = -1\n\
flat-volumes = no\n\
\n\
load-module module-null-sink sink_name=ledfx_sink sink_properties=device.description=LedFxNull\n\
set-default-sink ledfx_sink\n\
" > /home/ledfx/.config/pulse/daemon.conf

RUN printf "\
default-server = unix:/tmp/pulse/native\n\
autospawn = no\n\
" > /home/ledfx/.config/pulse/client.conf

ENV PULSE_RUNTIME_PATH=/tmp/pulse

# -----------------------------
# Expose UI
# -----------------------------
EXPOSE 8888

# -----------------------------
# Entrypoint
# -----------------------------
COPY --chmod=755 <<'EOF' /entrypoint.sh
#!/bin/bash
set -e

pulseaudio \
  --daemonize=no \
  --exit-idle-time=-1 \
  --log-target=stderr &

while [ ! -S /tmp/pulse/native ]; do
  sleep 0.1
done

echo "PulseAudio ready"

exec ledfx --host 0.0.0.0
EOF

ENTRYPOINT ["/entrypoint.sh"]
