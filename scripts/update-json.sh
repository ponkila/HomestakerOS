#!/usr/bin/env bash
# Script for updating the JSON files in the webui directory

config_dir="webui/public/nixosConfigurations"

# Default flags for the nix-command
declare -a nix_flags=(
  --accept-flake-config
  --extra-experimental-features 'nix-command flakes'
  --impure
  --no-warn-dirty
)

# Make config directory if doesn't exist
mkdir -p $config_dir

# Fetch nixosConfiguration attribute names from 'flake.nix'
mapfile -t attr_names < <(nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]')

names=()

if [ ${#attr_names[@]} -gt 0 ]; then
    for attr_name in "${attr_names[@]}"; do
      # Extract the name part of the nixosConfiguration entry
      name=$(echo "$attr_name" | cut -d '-' -f1)

      # Skip if the current name is the same as the previous one
      if [[ "$name" == "${names[-1]}" ]]; then
        continue
      else
        # Fetch and save the JSON data
        default_json="$config_dir/$name/default.json"
        json_data=$(nix eval --json .#nixosConfigurations."$attr_name".config.homestakeros "${nix_flags[@]}")
        mkdir -p "$config_dir/$name"
        echo "$json_data" | jq -r "." > "$default_json"
      fi
      names+=("$name")
    done
    # Save (host)names as JSON data
    printf '%s\n' "${names[@]}" | jq -R . | jq -s . > $config_dir/hostnames.json
else
    echo "[]" > $config_dir/hostnames.json
fi
