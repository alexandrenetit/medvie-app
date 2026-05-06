# syntax=docker/dockerfile:1

# Official Dart image required by this setup.
FROM dart:stable

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Default pinned version requested. Use DCM_VERSION=latest to install latest from apt.
ARG DCM_VERSION=1.36.0-1
ARG FLUTTER_VERSION=stable

ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_HOME=/opt/flutter
ENV FLUTTER_ROOT=/opt/flutter
ENV DCM_SDK_PATH=/opt/flutter/bin/cache/dart-sdk
ENV PUB_CACHE=/root/.pub-cache
ENV DCM_CONTAINER_MACHINE_ID=8f1b9f2e0f3a4d0e9c4c6e2f5a7b8c9d
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Base packages for DCM apt repository and Flutter SDK bootstrap.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      apt-transport-https \
      ca-certificates \
      curl \
      git \
      gnupg2 \
      unzip \
      wget \
      xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Official DCM GPG key and apt repository.
RUN wget -qO- https://dcm.dev/pgp-key.public \
      | gpg --dearmor -o /usr/share/keyrings/dcm.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/dcm.gpg arch=$(dpkg --print-architecture)] https://dcm.dev/debian stable main" \
      > /etc/apt/sources.list.d/dcm.list \
    && apt-get update \
    && if [[ "${DCM_VERSION}" == "latest" ]]; then \
         apt-get install -y --no-install-recommends dcm; \
       else \
         apt-get install -y --no-install-recommends "dcm=${DCM_VERSION}"; \
       fi \
    && rm -rf /var/lib/apt/lists/*

# Flutter SDK is needed because this is a Flutter project and imports package:flutter.
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "${FLUTTER_HOME}" \
    && git config --global --add safe.directory "${FLUTTER_HOME}" \
    && git config --global --add safe.directory /app \
    && flutter config --no-analytics \
    && flutter --version

WORKDIR /app

# Copy makes image runnable without compose; compose bind-mounts /app for local use.
COPY . .

# DCM activation is device-based. Keep /etc/machine-id stable for docker compose run --rm.
RUN printf '%s\n' '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "%s\n" "${DCM_CONTAINER_MACHINE_ID}" > /etc/machine-id' \
    'exec "$@"' \
    > /usr/local/bin/dcm-entrypoint \
    && chmod +x /usr/local/bin/dcm-entrypoint

ENTRYPOINT ["dcm-entrypoint"]

# Default command analyzes lib. Compose/script may override this command.
CMD ["dcm", "analyze", "lib", "--no-analytics", "--congratulate"]
