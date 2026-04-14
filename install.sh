#!/bin/bash
# bhkey installer
# Usage: curl -fsSL https://raw.githubusercontent.com/baekho-lim/bhkey/main/install.sh | bash

set -eu

REPO="baekho-lim/bhkey"
INSTALL_DIR="${BHKEY_INSTALL_DIR:-${HOME}/.local/bin}"
BINARY_NAME="bhkey"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${CYAN}bhkey installer${NC}"
echo ""

# macOS check
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: bhkey requires macOS (hidutil is macOS-only).${NC}"
    exit 1
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download latest release
echo "Downloading latest bhkey..."
if ! curl -fsSL "https://github.com/${REPO}/releases/latest/download/bhkey.sh" \
    -o "${INSTALL_DIR}/${BINARY_NAME}"; then
    echo -e "${RED}Error: Download failed. Check your internet connection.${NC}"
    exit 1
fi

chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
echo -e "${GREEN}Installed: ${INSTALL_DIR}/${BINARY_NAME}${NC}"
echo ""

# PATH check
if ! echo ":${PATH}:" | grep -q ":${INSTALL_DIR}:"; then
    echo -e "${YELLOW}Note: ${INSTALL_DIR} is not in your PATH.${NC}"
    echo "Add it by running:"
    echo ""
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
    echo ""
fi

echo "Next step — apply key mapping:"
echo ""
echo "  bhkey apply"
echo ""
echo "See README for post-apply setup (Korean keyboard users)."
