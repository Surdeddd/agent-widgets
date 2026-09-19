#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dist="$root/dist"
skip_build=0
for argument in "$@"; do
  case "$argument" in
    --skip-build) skip_build=1 ;;
    *) echo "usage: scripts/package.sh [--skip-build]" >&2; exit 2 ;;
  esac
done

version="$(sed -n 's/.*current = "\(.*\)".*/\1/p' "$root/Sources/AWCore/EngineVersion.swift")"
if [ -z "$version" ]; then
  echo "could not read the version from EngineVersion.swift" >&2
  exit 1
fi
binary="$root/.build/apple/Products/Release/aw"

if [ "$skip_build" -eq 0 ] || [ ! -x "$binary" ]; then
  swift build --package-path "$root" -c release --arch arm64 --arch x86_64 --product aw
fi
built="$("$binary" --version)"
if [ "$built" != "$version" ]; then
  echo "the binary says $built, EngineVersion.swift says $version: build again without --skip-build" >&2
  exit 1
fi

trash="$HOME/.Trash/agent-widgets"
if [ -d "$dist" ]; then
  mkdir -p "$trash"
  mv "$dist" "$trash/dist-$(date +%s)"
fi

engine() {
  local target="$1"
  mkdir -p "$target/bin"
  ditto "$binary" "$target/bin/aw"
  ditto "$root/Templates" "$target/Templates"
  ditto "$root/skills" "$target/skills"
  rsync -a --exclude .build --exclude .swiftpm "$root/Kit/" "$target/Kit/"
  rsync -a --exclude __pycache__ "$root/examples/widgets/" "$target/gallery/"
}

stamp() {
  sed -e "s/__VERSION__/$version/g" -e "s/__SHA256__/${2:-}/g" "$1"
}

npm_dir="$dist/npm"
engine "$npm_dir"
stamp "$root/packaging/npm/package.json" > "$npm_dir/package.json"
ditto "$root/packaging/npm/README.md" "$npm_dir/README.md"
ditto "$root/LICENSE" "$npm_dir/LICENSE"
(cd "$npm_dir" && npm pack --silent --pack-destination "$dist" > /dev/null)

mcpb_dir="$dist/mcpb"
engine "$mcpb_dir/engine"
stamp "$root/packaging/mcpb/manifest.json" > "$mcpb_dir/manifest.json"
ditto "$root/packaging/mcpb/icon.png" "$mcpb_dir/icon.png"
ditto "$root/LICENSE" "$mcpb_dir/LICENSE"
bundle="$dist/agent-widgets-$version.mcpb"
npx --yes @anthropic-ai/mcpb pack "$mcpb_dir" "$bundle" > /dev/null

sha="$(shasum -a 256 "$bundle" | cut -d' ' -f1)"
stamp "$root/packaging/registry/server.json" "$sha" > "$dist/server.json"

echo "version   $version"
echo "npm       $dist/agent-widgets-$version.tgz"
echo "mcpb      $bundle"
echo "sha256    $sha"
echo "registry  $dist/server.json"
