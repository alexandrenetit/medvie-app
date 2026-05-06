#!/usr/bin/env bash
set -euo pipefail

# Runs DCM fully inside a fixed Docker container.
# DCM Free activation is device-based, so this script uses docker compose exec,
# not docker compose run --rm.

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 not found. Install Docker Engine + Docker Compose inside WSL Ubuntu." >&2
  exit 1
fi

docker compose up -d dcm >/dev/null

license_output="$(docker compose exec -T dcm dcm license 2>&1 || true)"

if ! printf '%s\n' "${license_output}" | grep -Eiq '(^|[[:space:]])(Free|Pro|Starter|Teams|Enterprise)([[:space:]]|$)'; then
  cat >&2 <<'MSG'
DCM license is not active in the container cache.

Activate once with your Free license key:
  docker compose up -d dcm
  docker compose exec dcm dcm activate --license-key=YOUR_KEY

Get a Free key from:
  https://dcm.dev/pricing/

The activation data is kept by the fixed medvie-app-dcm container and persisted in Docker volumes.
No license key should be committed or written into project files.
MSG
  exit 1
fi

# No args: run default analysis.
# With args: override command, for example:
#   ./run_dcm.sh dcm analyze test --no-analytics --congratulate
if [[ "$#" -eq 0 ]]; then
  exec docker compose exec dcm bash -c \
    'flutter pub get --enforce-lockfile && dcm analyze lib --no-analytics --congratulate'
fi

exec docker compose exec dcm "$@"
