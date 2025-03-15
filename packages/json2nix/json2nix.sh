#!/usr/bin/env bash
# Script for converting a JSON data to Nix expression

set -o pipefail

# Read JSON data from stdin if available
if [ -p /dev/stdin ]; then
  json_data=$(</dev/stdin)
else
  echo "error: JSON data not provided."
  exit 1
fi

# Convert JSON to Nix expression using a here-document to avoid double escaping
nix_expr=$(nix-instantiate --eval --expr "builtins.fromJSON ''$json_data''") || exit 1

# Print to stdout
echo "$nix_expr"
