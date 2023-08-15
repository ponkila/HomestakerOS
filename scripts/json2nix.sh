#!/usr/bin/env bash
# Script for creating a 'nixosConfigurations/<hostname>/default.nix' from JSON data

set -o pipefail

# Check argument count
if [ $# -ne 1 ]; then
  echo "Usage: cat foo.json | nix run .#json2nix -- <hostname>"
  exit 1
fi

hostname="$1"
default_nix="nixosConfigurations/$hostname/default.nix"

# Create the $hostname folder if it doesn't exist
if [ ! -d "$(dirname "$default_nix")" ]; then
  mkdir -p "$(dirname "$default_nix")"
fi

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

# Create default.nix file
cat > "$default_nix" << EOF
{ pkgs, config, inputs, lib, ... }:
{
  homestakeros = $nix_expr;
}
EOF

