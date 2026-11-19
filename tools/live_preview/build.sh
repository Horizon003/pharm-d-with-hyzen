#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
flutter_bin=${HYZEN_FLUTTER_BIN:-flutter}
preview_dir="$repo_dir/hyzen_flutter/build/live-preview"
site_base=${HYZEN_PREVIEW_BASE_HREF:-/pharm-d-with-hyzen/}
if [[ "$site_base" != /*/ || "$site_base" == *'..'* ]]; then
  printf 'HYZEN_PREVIEW_BASE_HREF must be an absolute directory path ending in /.\n' >&2
  exit 2
fi
cd "$repo_dir/hyzen_flutter"
version=$(sed -n 's/^version: //p' pubspec.yaml)
"$flutter_bin" pub get
"$flutter_bin" build web --release --pwa-strategy=none --no-web-resources-cdn \
  --target lib/main_account_review.dart --base-href "${site_base}app/" \
  --dart-define=HYZEN_REVIEW_ROUTE=/home --dart-define=HYZEN_APP_VERSION="$version"
rm -rf "$preview_dir"
mkdir -p "$preview_dir/app"
cp -a build/web/. "$preview_dir/app/"
cp "$repo_dir/tools/live_preview/index.html" "$preview_dir/index.html"
git -C "$repo_dir" rev-parse HEAD > "$preview_dir/source-commit.txt"
printf 'Live preview output: %s\n' "$preview_dir"
