#!/usr/bin/env bash
set -Eeuo pipefail
STABLE="${1:-}"; SHADOW="${2:-}"; PATH_TO_GET="${3:-/health}"
[[ -n "$STABLE" && -n "$SHADOW" && "$PATH_TO_GET" == /* ]] || { echo "Usage: $0 <stable-url> <shadow-url> [/GET-path]" >&2; exit 2; }
command -v curl >/dev/null
echo "Stable response:"
curl --fail --silent --show-error --output /dev/null --write-out "HTTP %{http_code}\n" "${STABLE%/}${PATH_TO_GET}"
echo "Shadow replay response:"
curl --fail --silent --show-error --output /dev/null --write-out "HTTP %{http_code}\n" "${SHADOW%/}${PATH_TO_GET}"
echo "Manual GET replay completed. This is not automatic live traffic mirroring."
