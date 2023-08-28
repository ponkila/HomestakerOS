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

# Catch Ctrl+C signal to run cleanup
cleanup() {
    rm -r "$config_dir"
    exit 1
}
trap cleanup SIGINT

# Make config directory if doesn't exist
mkdir -p $config_dir

# Fetch hostnames from 'flake.nix'
mapfile -t hostnames < <(nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]')

if [ ${#hostnames[@]} -gt 0 ]; then
    printf '%s\n' "${hostnames[@]}" | jq -R . | jq -s . > $config_dir/hostnames.json

    # Get and save the JSON data
    for hostname in "${hostnames[@]}"; do
      default_json="$config_dir/$hostname/default.json"
      json_data=$(nix eval --json .#nixosConfigurations."$hostname".config.homestakeros "${nix_flags[@]}")
      echo "$json_data" | jq -r "." > "$default_json"
    done
else
    echo "[]" > $config_dir/hostnames.json
fi