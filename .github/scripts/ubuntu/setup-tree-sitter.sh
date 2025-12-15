#!/bin/bash
set -e

# Setup script for tree-sitter dependencies (Ubuntu/Debian)
# Works for both GitHub Actions (with --sudo flag) and devcontainer (without --sudo flag)
# Options:
#   --sudo: Use sudo for package installation commands
#   --cli:  Install tree-sitter-cli via npm (optional)
#   --build: Build and install the Tree-sitter C runtime from source when distro packages are missing (optional)

SUDO=""
INSTALL_CLI=false
BUILD_FROM_SOURCE=false

for arg in "$@"; do
  case $arg in
    --sudo)
      SUDO="sudo"
      ;;
    --cli)
      INSTALL_CLI=true
      ;;
    --build)
      BUILD_FROM_SOURCE=true
      ;;
  esac
done

have_cmd() { command -v "$1" >/dev/null 2>&1; }

have_tree_sitter() {
  [ -f /usr/include/tree-sitter/api.h ] && return 0
  [ -f /usr/local/include/tree-sitter/api.h ] && return 0
  [ -f /usr/local/include/tree-sitter/lib/include/api.h ] && return 0
  ldconfig -p 2>/dev/null | grep -q libtree-sitter && return 0 || return 1
}

install_tree_sitter_from_source() {
  echo "[ubuntu] Attempting to build and install tree-sitter from source..."
  tmpdir=$(mktemp -d /tmp/tree-sitter-src-XXXX)
  trap 'rm -rf "$tmpdir"' EXIT
  git clone --depth 1 https://github.com/tree-sitter/tree-sitter.git "$tmpdir" || return 1
  pushd "$tmpdir" >/dev/null || return 1
  if ! make; then
    echo "[ubuntu] ERROR: 'make' failed while building tree-sitter" >&2
    popd >/dev/null
    return 1
  fi

  $SUDO mkdir -p /usr/local/include/tree-sitter
  $SUDO cp -r lib/include/* /usr/local/include/tree-sitter/ || true
  $SUDO cp -a lib/libtree-sitter.* /usr/local/lib/ 2>/dev/null || true
  if have_cmd ldconfig; then
    $SUDO ldconfig || true
  fi

  popd >/dev/null
  echo "[ubuntu] tree-sitter built and installed to /usr/local (headers + libs)."
  return 0
}

echo "Installing tree-sitter system library and dependencies..."
$SUDO apt-get update -y
if ! $SUDO apt-get install -y \
  build-essential \
  pkg-config \
  # libtree-sitter-dev is optional when building from source via --build
  $( [ "$BUILD_FROM_SOURCE" = false ] && echo "libtree-sitter-dev" ) \
  wget \
  gcc \
  g++ \
  make \
  zlib1g-dev \
  libssl-dev \
  libreadline-dev \
  libyaml-dev \
  libxml2-dev \
  libxslt1-dev \
  libcurl4-openssl-dev \
  software-properties-common \
  libffi-dev; then
  echo "ERROR: apt-get failed to install required packages."
  echo "Please check your network, package sources, and re-run this script."
  exit 1
fi

# If the user requested a source-build, skip installing libtree-sitter-dev
if [ "$BUILD_FROM_SOURCE" = true ]; then
  echo "[ubuntu] --build specified; skipping distro package 'libtree-sitter-dev' and building tree-sitter from source."
fi

# Ensure tree-sitter is available; if not, attempt to build from source
if ! have_tree_sitter; then
  if [ "$BUILD_FROM_SOURCE" = true ]; then
    echo "[ubuntu] tree-sitter not found in system paths; attempting to build from source as requested (--build)."
    if ! install_tree_sitter_from_source; then
      echo "[ubuntu] ERROR: Failed to provide tree-sitter runtime/library. Aborting." >&2
      exit 1
    fi
  else
    echo "[ubuntu] ERROR: tree-sitter runtime (headers/libs) not found."
    echo "Install the appropriate distro package (e.g., libtree-sitter-dev) or re-run this script with --build to compile from source."
    exit 1
  fi
fi

# Install tree-sitter CLI via npm (optional)
if [ "$INSTALL_CLI" = true ]; then
  echo "Installing tree-sitter-cli via npm..."
  $SUDO npm install -g tree-sitter-cli
else
  echo "Skipping tree-sitter-cli installation (use --cli flag to install)"
fi

echo "Building and installing tree-sitter-toml..."
cd /tmp
wget -q https://github.com/tree-sitter-grammars/tree-sitter-toml/archive/refs/heads/master.zip
unzip -q master.zip
cd tree-sitter-toml-master

# Compile both parser.c and scanner.c
gcc -fPIC -I./src -c src/parser.c -o parser.o
gcc -fPIC -I./src -c src/scanner.c -o scanner.o

# Link both object files into the shared library
gcc -shared -o libtree-sitter-toml.so parser.o scanner.o

# Install to system
$SUDO cp libtree-sitter-toml.so /usr/local/lib/
$SUDO ldconfig

echo ""
echo "Tree-sitter setup complete!"
echo ""
echo "Detected library paths:"

# Detect and report tree-sitter runtime library location
if [ -f /usr/lib/x86_64-linux-gnu/libtree-sitter.so.0 ]; then
  echo "  TREE_SITTER_RUNTIME_LIB=/usr/lib/x86_64-linux-gnu/libtree-sitter.so.0"
elif [ -f /usr/lib/x86_64-linux-gnu/libtree-sitter.so ]; then
  echo "  TREE_SITTER_RUNTIME_LIB=/usr/lib/x86_64-linux-gnu/libtree-sitter.so"
elif [ -f /usr/lib/libtree-sitter.so.0 ]; then
  echo "  TREE_SITTER_RUNTIME_LIB=/usr/lib/libtree-sitter.so.0"
elif [ -f /usr/lib/libtree-sitter.so ]; then
  echo "  TREE_SITTER_RUNTIME_LIB=/usr/lib/libtree-sitter.so"
else
  echo "  WARNING: Could not find libtree-sitter runtime library!"
fi

echo "  TREE_SITTER_TOML_PATH=/usr/local/lib/libtree-sitter-toml.so"
