#!/usr/bin/env bash
# Script for generating operator key pair for the SSV node

# Check arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: nix run .#init-ssv -- <hostname>"
    exit 1
fi

hostname="$1"
config_dir="webui/nixosConfigurations/$hostname"
private_key_path="gitignore/$hostname/ssv_operator_key"

# Validate hostname
if [ ! -d "$config_dir" ]; then
    echo "error: host '$hostname' does not exist, build it first."
    exit 1
fi

# Check if JSON data exists
default_json="$config_dir/default.json"
if [ ! -f "$default_json" ]; then
    echo "error: 'default.json' does not exist for host '$hostname'."
    exit 1
fi

# Generate SSV node operator keys
keys=$(ssvnode generate-operator-keys 2>/dev/null)

# Extract the keys
public_key=$(echo "$keys" | grep -o '{"pk":.*}' | jq -r '.pk')
private_key=$(echo "$keys" | grep -o '{"sk":.*}' | jq -r '.sk')

# Save the public key
echo "$public_key" > "$config_dir/ssv_operator_key.pub"

# Fetch the configured path from the JSON data
target=$(jq -r '.addons."ssv-node".privateKeyFile' "$config_dir/default.json")

# Save the private key
mkdir -p "$(dirname "$private_key_path")"
echo "$private_key" > "$private_key_path"

# Print instructions for the user
cmd="scp $private_key_path core@$hostname:$target"
echo -e "The private key has been generated. Transfer it securely to the target machine:\n\`$cmd\`"