#!/usr/bin/env bash
# Setup script for java-tree-sitter JAR files
# Run this script to download the required JARs for the Java backend

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JARS_DIR="${SCRIPT_DIR}/jars"
# Check https://central.sonatype.com/artifact/io.github.tree-sitter/jtreesitter/versions for latest
JTREESITTER_VERSION="${JTREESITTER_VERSION:-0.23.2}"
JAR_FILE="${JARS_DIR}/jtreesitter-${JTREESITTER_VERSION}.jar"
MAVEN_URL="https://repo1.maven.org/maven2/io/github/tree-sitter/jtreesitter/${JTREESITTER_VERSION}/jtreesitter-${JTREESITTER_VERSION}.jar"

mkdir -p "${JARS_DIR}"

# Remove any existing corrupted JAR
if [[ -f "${JAR_FILE}" ]]; then
  echo "Removing existing JAR file..."
  rm -f "${JAR_FILE}"
fi

echo "Downloading java-tree-sitter v${JTREESITTER_VERSION} from Maven Central..."
echo "URL: ${MAVEN_URL}"

# Download with error handling
if ! curl -fSL -o "${JAR_FILE}" "${MAVEN_URL}"; then
  echo "ERROR: Failed to download JAR file"
  echo "Please check the version number and your internet connection"
  exit 1
fi

# Verify the download
JAR_SIZE=$(stat -c%s "${JAR_FILE}" 2>/dev/null || stat -f%z "${JAR_FILE}" 2>/dev/null)
echo "Downloaded file size: ${JAR_SIZE} bytes"

if [[ "${JAR_SIZE}" -lt 10000 ]]; then
  echo "ERROR: Downloaded file is too small (${JAR_SIZE} bytes). Expected > 100KB."
  echo "The download may have failed. Please check the URL manually:"
  echo "  ${MAVEN_URL}"
  rm -f "${JAR_FILE}"
  exit 1
fi

# Verify it's a valid JAR/ZIP file
if ! jar tf "${JAR_FILE}" > /dev/null 2>&1; then
  echo "ERROR: Downloaded file is not a valid JAR file"
  rm -f "${JAR_FILE}"
  exit 1
fi

echo ""
echo "SUCCESS! Downloaded to: ${JAR_FILE}"
echo ""
echo "============================================================"
echo "IMPORTANT: Grammar Loading with Java Backend"
echo "============================================================"
echo ""
echo "The Java backend has a limitation: grammar .so files compiled for"
echo "C/Ruby (from luarocks, npm, etc.) cannot be loaded directly because"
echo "they have unresolved dependencies on libtree-sitter symbols."
echo ""
echo "Options:"
echo ""
echo "1. Use the MRI or FFI backend (recommended for now)"
echo "   These backends handle dynamic linking correctly."
echo ""
echo "2. Use java-tree-sitter grammar JARs from Maven Central"
echo "   Check: https://central.sonatype.com/search?q=tree-sitter"
echo "   Download grammar JARs and place them in: ${JARS_DIR}"
echo ""
echo "============================================================"
echo ""
echo "To use with TreeHaver, set the environment variable:"
echo ""
echo "  export TREE_SITTER_JAVA_JARS_DIR=\"${JARS_DIR}\""
echo ""
echo "Add to your .envrc:"
echo ""
echo "  export TREE_SITTER_JAVA_JARS_DIR=\"${JARS_DIR}\""
echo "  export LD_LIBRARY_PATH=\"/path/to/libtree-sitter/lib:\$LD_LIBRARY_PATH\""
echo "  export JAVA_OPTS=\"--enable-native-access=ALL-UNNAMED\""
echo ""
echo "Then use JRuby to test:"
echo ""
echo "  jruby -e \"require 'tree_haver'; puts TreeHaver::Backends::Java.available?\""

