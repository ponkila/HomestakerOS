#!/usr/bin/env bash

# Check arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: nix run .#init-ssv -- <hostname>"
    exit 1
fi

hostname="$1"
output_dir="packages/frontend/webui/nixosConfigurations"

# Validate hostname
if [ ! -d "$output_dir/$hostname" ]; then
    echo "error: host '$hostname' does not exist."
    exit 1
fi

# Generate SSV node operator keys
keys=$(ssvnode generate-operator-keys)

# Extract the keys
public_key=$(echo "$keys" | grep -o '{"pk":.*}' | jq -r '.pk')
private_key=$(echo "$keys" | grep -o '{"sk":.*}' | jq -r '.sk')

# Save the public key
echo "$public_key" > "$output_dir/$hostname/ssv_operator_key.pub"

# Print the private key
echo "Private Key: $private_key"
