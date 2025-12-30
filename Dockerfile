# Start from Python slim
FROM python:3.11-slim

LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="LedFx with snapclient support and virtual ALSA loopback"

# Install OS deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      build-essential \
      alsa-utils \
      alsa-base \
      alsa-tools \
      libasound2-dev \
      snapclient \
      && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd --create-home --shell /bin/bash ledfx

USER ledfx
WORKDIR /home/ledfx

# Install latest LedFx from pip
RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install ledfx

# Set up a virtual ALSA loopback device
# This requires the host to load the snd-aloop kernel module:
#   sudo modprobe snd-aloop
# The loopback device will appear as hw:Loopback
RUN mkdir -p /home/ledfx/.config/alsa

# Copy a simple .asoundrc to define default loopback device
RUN echo '\
pcm.!default {\n\
  type hw\n\
  card Loopback\n\
}\n\
ctl.!default {\n\
  type hw\n\
  card Loopback\n\
}\n' > /home/ledfx/.config/alsa/.asoundrc

# Expose LedFx UI
EXPOSE 8888

# Environment variable so LedFx uses ALSA
# (you can make LedFx use this by selecting ALSA input)
ENV ALSA_PCM_CARD=Loopback
ENV ALSA_PCM_DEVICE=0

# Entrypoint
ENTRYPOINT ["ledfx"]
CMD ["--open-ui", "--host", "0.0.0.0"]
