#!/usr/bin/env bash
# Script for generating operator key pair for the SSV node

# Check arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: nix run .#init-ssv -- <hostname>"
    exit 1
fi

hostname="$1"
config_dir="webui/nixosConfigurations"

# Validate hostname
if [ ! -d "$config_dir/$hostname" ]; then
    echo "error: host '$hostname' does not exist, build it first."
    exit 1
fi

# Check if JSON data exists
default_json="$config_dir/$hostname/default.json"
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
echo "$public_key" > "$config_dir/$hostname/ssv_operator_key.pub"

# Fetch the configured path from the JSON data
private_key_target=$(jq -r '.addons."ssv-node".privateKeyFile' "$config_dir/$hostname/default.json")

# Store the private key to a temporary directory
temp_dir=$(mktemp -d)
private_key_source="$temp_dir/ssv_operator_key"
echo "$private_key" > "$private_key_source"

# Print instructions for the user
scp_cmd="scp $private_key_source core@$hostname:$private_key_target"
echo -e "The private key has been generated. Transfer it securely to the target machine:\n\`$scp_cmd\`"