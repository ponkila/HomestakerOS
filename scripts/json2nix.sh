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

# Validate JSON data, has better errors than builtins.fromJSON
echo "$json_data" | json_pp > /dev/null || exit 1

# Escape double quotes
esc_json_data="${json_data//\"/\\\"}"

# Convert JSON to Nix expression
nix_expr=$(nix-instantiate --eval --expr "builtins.fromJSON \"$esc_json_data\"") || exit 1

# Print to stdout
echo "$nix_expr"