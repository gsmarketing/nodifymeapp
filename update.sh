#!/bin/bash
# Nodify.Me agent updater.
#
# Updates an installed agent by re-running the official installer with this
# server's existing settings, so the new binary goes through the same checksum
# and signature verification as a fresh install. Safe to run at any time.
#
# Generated on each release; local edits to a published copy are overwritten.
#
#   sudo ./update.sh                 # latest release
#   sudo ./update.sh v0.1.7          # a specific release

set -euo pipefail

ENV_FILE="/etc/nodifyme/agent.env"
INSTALL_URL="https://raw.githubusercontent.com/gsmarketing/nodifymeapp/main/install.sh"
VERSION="${1:-latest}"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
    echo "No agent installation found ($ENV_FILE is missing)." >&2
    echo "Install the agent from the Nodify.Me web app instead." >&2
    exit 1
fi

[[ "$VERSION" =~ ^[0-9] ]] && VERSION="v$VERSION"
if [[ ! "$VERSION" =~ ^(latest|v[0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    echo "Invalid version '$VERSION'. Use 'latest' or something like v0.1.7." >&2
    exit 1
fi

# Read the two settings without executing the file
read_setting() { grep -m1 "^$1=" "$ENV_FILE" | cut -d= -f2-; }
API_URL="$(read_setting API_URL)"
TOKEN="$(read_setting AGENT_AUTH_TOKEN)"

if [[ -z "$API_URL" || -z "$TOKEN" ]]; then
    echo "$ENV_FILE does not contain API_URL and AGENT_AUTH_TOKEN; cannot update." >&2
    echo "Get a fresh install command from the server's page in the Nodify.Me web app." >&2
    exit 1
fi

for tool in curl sha256sum openssl; do
    command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required." >&2; exit 1; }
done

echo "Updating the Nodify.Me agent to: $VERSION"
# pipefail: a failed download must stop the update, not run an empty script
curl -fsSL "$INSTALL_URL" | bash -s -- --api-url "$API_URL" --token "$TOKEN" --version "$VERSION"
