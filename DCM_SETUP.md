# DCM Docker Setup for Flutter on WSL Ubuntu

This setup runs Dart Code Metrics (DCM) inside Docker on WSL2 Ubuntu.
No DCM executable is installed on the host.

It targets the DCM Free plan only:
- 100 unique lint rules
- 22 code metrics
- console output
- local developer activation

## Prerequisites

Use WSL2 with Ubuntu 22.04 or newer.

Install Docker Engine and Docker Compose v2 inside WSL Ubuntu, then verify:

```bash
docker --version
docker compose version
```

Run all commands from the Flutter project root, where these files exist:

```text
pubspec.yaml
analysis_options.yaml
lib/
test/
Dockerfile
docker-compose.yml
run_dcm.sh
```

## Build the Image

Default build uses the pinned DCM version requested by this setup: `1.36.0-1`.

```bash
docker compose build dcm
```

To install the newest DCM package available from the official DCM apt repository instead of the pinned default:

```bash
DCM_VERSION=latest docker compose build --no-cache dcm
```

To pin another version:

```bash
DCM_VERSION=1.37.0-1 docker compose build --no-cache dcm
```

## Why the Image Includes Flutter

The base image is `dart:stable`, as required.

This is still a Flutter project, so the image also installs Flutter SDK inside the container.
Without Flutter SDK, DCM may fail to resolve imports such as:

```dart
import 'package:flutter/material.dart';
```

The container sets:

```bash
FLUTTER_ROOT=/opt/flutter
DCM_SDK_PATH=/opt/flutter/bin/cache/dart-sdk
```

## Activate the Free DCM License Once

Get a Free plan key from:

```text
https://dcm.dev/pricing/
```

Choose the Free plan and follow the DCM checkout/email flow. DCM states that Free and Pro plans do not require a Teams account.

Start the fixed DCM container:

```bash
docker compose up -d dcm
```

Activate inside the fixed container:

```bash
docker compose exec dcm dcm activate --license-key=YOUR_KEY
```

Check activation:

```bash
docker compose exec dcm dcm license
```

Do not put the license key in:
- `Dockerfile`
- `docker-compose.yml`
- shell history shared with others
- committed project files
- CI logs

## License Persistence

The compose file mounts this named Docker volume:

```yaml
dcm_home:/root/.dcm
root_config:/root/.config
root_local_share:/root/.local/share
```

The compose service also sets a fixed hostname:

```yaml
hostname: medvie-app-dcm
```

The compose service uses a fixed container:

```yaml
container_name: medvie-app-dcm
```

The image entrypoint also writes a stable `/etc/machine-id` on container start.
This matters because DCM activation is device-based.

Inside the container, DCM runs as `root`, so `/root/.dcm` is the local DCM home used for license/config data.
The extra XDG volumes persist alternate Linux config/data paths used by CLI tools:

```text
/root/.config
/root/.local/share
```

Use `docker compose exec` against the fixed running container for normal work.
Avoid `docker compose run --rm` for DCM licensing, because it creates a new one-off container and may change the device identity.

List volumes:

```bash
docker volume ls
```

Inspect the DCM volume:

```bash
docker volume inspect medvie-app_dcm_home
```

The exact Docker volume name may differ if your compose project name differs.

## Device ID Notes

DCM license activation is device-based.

For normal local Docker usage, the fixed container plus persisted DCM/config volumes avoids reactivation.

If DCM reports the license inactive after a major Docker/WSL reset, Docker volume deletion, or DCM renewal event, activate again:

```bash
docker compose up -d dcm
docker compose exec dcm dcm activate --license-key=YOUR_KEY
```

Free plan deactivation is not needed; DCM documentation says Free users can uninstall the tool or activate another key.

Do not try to fake a device ID with fragile container tricks.
Persist the DCM home volume and reactivate only when DCM itself requires it.

## Run Analysis

Direct command:

```bash
docker compose up -d dcm
docker compose exec dcm bash -c "flutter pub get --enforce-lockfile && dcm analyze lib --no-analytics --congratulate"
```

Helper script:

```bash
chmod +x ./run_dcm.sh
./run_dcm.sh
```

The default command runs:

```bash
flutter pub get --enforce-lockfile
dcm analyze lib --no-analytics --congratulate
```

`--enforce-lockfile` prevents dependency resolution from rewriting `pubspec.lock`.
Generated `.dart_tool` data is stored in a Docker named volume, not in the host project directory.

## Override the Command

Analyze another directory:

```bash
./run_dcm.sh dcm analyze test --no-analytics --congratulate
```

Show license:

```bash
docker compose exec dcm dcm license
```

Preview metrics:

```bash
./run_dcm.sh dcm init metrics-preview lib
```

Preview lints:

```bash
./run_dcm.sh dcm init lints-preview lib
```

## Add the Command to PATH in WSL

Create a local bin directory if needed:

```bash
mkdir -p "$HOME/.local/bin"
```

Create a symlink:

```bash
ln -sf "$(pwd)/run_dcm.sh" "$HOME/.local/bin/run_dcm"
```

Ensure `~/.local/bin` is in PATH:

```bash
grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" \
  || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
```

Reload shell config:

```bash
source "$HOME/.bashrc"
```

Run from the project root:

```bash
run_dcm
```

## Free Plan Configuration

The Free plan supports manual rule configuration in `analysis_options.yaml`.

Do not rely on paid-only presets or Teams/CI keys for this local setup.
Use individual DCM lint rules and metrics that are available in the Free plan.

Example shape:

```yaml
dcm:
  metrics:
    cyclomatic-complexity: 15
    maximum-nesting-level: 5
    number-of-parameters: 6
  rules:
    - avoid-empty-build-when
    - avoid-unnecessary-setstate
```

Adjust rules according to the official DCM rule list and your project policy.

## Cleanup

Remove stopped containers:

```bash
docker container prune
```

Remove the DCM license/config volume only if you intentionally want to reset activation:

```bash
docker volume rm medvie-app_dcm_home
```

After removing that volume, activate again.

## References

Official DCM Linux install:
https://dcm.dev/docs/getting-started/installation/linux/

Official DCM Free plan setup:
https://dcm.dev/docs/getting-started/for-developers/free-plan/

Official DCM license activation:
https://dcm.dev/docs/getting-started/license/

Official DCM pricing:
https://dcm.dev/pricing/
