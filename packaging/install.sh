#!/usr/bin/env sh
# WorkLoom CLI installer.
#
#   curl -fsSL https://raw.githubusercontent.com/catesandrew/work-loom-releases/main/packaging/install.sh | sh
#
# Prefer inspect-before-run:
#   curl -fsSL <url> -o install.sh && less install.sh && sh install.sh
#
# Downloads the prebuilt, self-contained `wl` binary for your platform from the
# GitHub Release, verifies its SHA-256 against the published SHA256SUMS.txt, and
# installs it to ~/.workloom/bin (override with INSTALL_DIR). No Node required —
# the binary bundles its own runtime.
#
# Env overrides:
#   VERSION=cli-v0.2.0   pin a release tag (default: latest)
#   INSTALL_DIR=/usr/local/bin   install location (default: ~/.workloom/bin)
set -eu

# Public mirror repo (source lives in the private catesandrew/work-loom repo).
# Anonymous curl|bash can't reach private-repo release assets, so binaries +
# checksums are mirrored here by the CLI Release workflow.
REPO="catesandrew/work-loom-releases"
BINARY="wl"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.workloom/bin}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$1" >&2; }
err() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# --- detect platform -------------------------------------------------------
os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
  Linux)  os="linux" ;;
  Darwin) os="darwin" ;;
  MINGW* | MSYS* | CYGWIN*) err "Windows: download wl-windows-x64.exe from the Releases page, or install via 'npm i -g @workloom/cli'." ;;
  *) err "unsupported OS: $os" ;;
esac

case "$arch" in
  x86_64 | amd64) arch="x64" ;;
  arm64 | aarch64) arch="arm64" ;;
  *) err "unsupported architecture: $arch" ;;
esac

asset="${BINARY}-${os}-${arch}"

# --- need one of curl/wget -------------------------------------------------
if command -v curl >/dev/null 2>&1; then
  dl() { curl -fsSL "$1" -o "$2"; }
  fetch() { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
  dl() { wget -qO "$2" "$1"; }
  fetch() { wget -qO- "$1"; }
else
  err "need curl or wget installed"
fi

# --- resolve release tag ---------------------------------------------------
if [ -n "${VERSION:-}" ]; then
  tag="$VERSION"
else
  info "resolving latest release"
  tag="$(fetch "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' | head -1 | cut -d '"' -f 4)"
  [ -n "$tag" ] || err "could not resolve latest release tag (set VERSION=cli-vX.Y.Z to pin)"
fi

base="https://github.com/${REPO}/releases/download/${tag}"
info "installing ${BINARY} ${tag} (${os}-${arch})"

# --- download binary + checksums into a temp dir ---------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

dl "${base}/${asset}" "${tmp}/${asset}" || err "download failed: ${base}/${asset}"
dl "${base}/SHA256SUMS.txt" "${tmp}/SHA256SUMS.txt" || err "download failed: SHA256SUMS.txt"

# --- verify checksum -------------------------------------------------------
expected="$(grep " ${asset}\$" "${tmp}/SHA256SUMS.txt" | awk '{print $1}')"
[ -n "$expected" ] || err "no checksum for ${asset} in SHA256SUMS.txt"

if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "${tmp}/${asset}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "${tmp}/${asset}" | awk '{print $1}')"
else
  err "need sha256sum or shasum to verify the download"
fi

[ "$expected" = "$actual" ] || err "checksum mismatch for ${asset}
  expected: ${expected}
  actual:   ${actual}"
info "checksum verified"

# --- install ---------------------------------------------------------------
mkdir -p "$INSTALL_DIR"
install -m 0755 "${tmp}/${asset}" "${INSTALL_DIR}/${BINARY}" 2>/dev/null \
  || { cp "${tmp}/${asset}" "${INSTALL_DIR}/${BINARY}" && chmod 0755 "${INSTALL_DIR}/${BINARY}"; }

info "installed to ${INSTALL_DIR}/${BINARY}"

# --- PATH hint -------------------------------------------------------------
case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ;;
  *)
    warn "${INSTALL_DIR} is not on your PATH. Add it:"
    printf '  export PATH="%s:$PATH"\n' "$INSTALL_DIR" >&2
    ;;
esac

if "${INSTALL_DIR}/${BINARY}" --version >/dev/null 2>&1; then
  info "run '${BINARY} --help' to get started"
else
  warn "installed, but '${BINARY} --version' did not run cleanly"
fi
