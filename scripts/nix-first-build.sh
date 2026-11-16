#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLAKE_FILE="${REPO_ROOT}/flake.nix"
NIX_FLAGS=(--extra-experimental-features "nix-command flakes")

if ! command -v nix >/dev/null 2>&1; then
  echo "error: nix is not installed or not on PATH" >&2
  exit 1
fi

if [ ! -f "${FLAKE_FILE}" ]; then
  echo "error: ${FLAKE_FILE} not found" >&2
  exit 1
fi

cd "${REPO_ROOT}"

if grep -q 'vendorHash = pkgs.lib.fakeHash;' "${FLAKE_FILE}"; then
  echo "==> Building with placeholder vendorHash to discover the real hash"
  build_log="$(mktemp)"
  trap 'rm -f "${build_log}"' EXIT

  if nix "${NIX_FLAGS[@]}" build .#default -L --no-link 2>&1 | tee "${build_log}"; then
    echo "error: build succeeded with fakeHash, which is unexpected" >&2
    exit 1
  fi

  real_hash="$(grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' "${build_log}" | awk '{print $2}' | tail -n 1)"
  if [ -z "${real_hash}" ]; then
    echo "error: build failed without a hash mismatch, see the log above" >&2
    exit 1
  fi

  echo "==> Setting vendorHash to ${real_hash}"
  sed -i.bak "s|vendorHash = pkgs.lib.fakeHash;|vendorHash = \"${real_hash}\";|" "${FLAKE_FILE}"
  rm -f "${FLAKE_FILE}.bak"
else
  echo "==> vendorHash is already set, skipping hash discovery"
fi

echo "==> Building package"
nix "${NIX_FLAGS[@]}" build .#default -L

echo "==> Running built binary"
./result/bin/wtp --version

echo "==> Running flake checks"
nix "${NIX_FLAGS[@]}" flake check -L

echo "==> Done"
