FROM python:3.11-slim

LABEL description="LedFx (latest) + Snapclient + PulseAudio null sink"

# ----------------------------
# System dependencies
# ----------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      pulseaudio \
      pulseaudio-utils \
      snapclient \
      ca-certificates \
      build-essential \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Create non-root user
# ----------------------------
RUN useradd --create-home --shell /bin/bash ledfx
USER ledfx
WORKDIR /home/ledfx

# ----------------------------
# Install latest LedFx
# ----------------------------
RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install ledfx

# ----------------------------
# PulseAudio configuration
# ----------------------------
RUN mkdir -p /home/ledfx/.config/pulse

# PulseAudio daemon config
RUN printf "\
daemonize = no\n\
exit-idle-time = -1\n\
flat-volumes = no\n\
\n\
load-module module-null-sink sink_name=ledfx_sink sink_properties=device.description=LedFxNull\n\
\n\
set-default-sink ledfx_sink\n\
" > /home/ledfx/.config/pulse/daemon.conf

# Client config
RUN printf "\
default-server = unix:/tmp/pulse/native\n\
autospawn = no\n\
" > /home/ledfx/.config/pulse/client.conf

# ----------------------------
# Runtime directories
# ----------------------------
ENV PULSE_RUNTIME_PATH=/tmp/pulse
RUN mkdir -p /tmp/pulse

# ----------------------------
# Expose LedFx UI
# ----------------------------
EXPOSE 8888

# ----------------------------
# Startup script
# ----------------------------
COPY --chmod=755 <<'EOF' /home/ledfx/start.sh
#!/bin/bash
set -e

# Start PulseAudio
pulseaudio \
  --log-level=error \
  --log-target=stderr \
  --exit-idle-time=-1 \
  --daemonize=no &

# Wait for PulseAudio socket
while [ ! -S /tmp/pulse/native ]; do
  sleep 0.1
done

echo "PulseAudio ready"

# Start LedFx
exec ledfx --host 0.0.0.0 --open-ui
EOF

ENTRYPOINT ["/home/ledfx/start.sh"]
