#!/usr/bin/env bash
# Script for updating the JSON files in the webui directory

config_dir="webui/nixosConfigurations"

# Default flags for the nix-command
declare -a nix_flags=(
  --accept-flake-config
  --extra-experimental-features 'nix-command flakes'
  --impure
  --no-warn-dirty
)

# Generate a JSON-formatted file containing the hostnames
hostnames=$(find nixosConfigurations -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
echo "$hostnames" | jq -R . | jq -s . > $config_dir/hostnames.json

# Get and save the JSON data
for hostname in $hostnames; do
  default_json="$config_dir/$hostname/default.json"
  json_data=$(nix eval --json .#nixosConfigurations."$hostname".config.homestakeros "${nix_flags[@]}")
  echo "$json_data" | jq -r "." > "$default_json"
done