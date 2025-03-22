#!/usr/bin/env bash
# Script to generate SSV operator keys with a password

# Define file paths
PRIVATE_KEY_PATH="ssv_operator_key"
PUBLIC_KEY_PATH="ssv_operator_key.pub"
PASSWORD_PATH="password"
TEMP_ENCRYPTED_PATH="encrypted_private_key.json"

# Check if password is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: init-ssv <password>"
    exit 1
fi

# Save password to file
echo "$1" > "$PASSWORD_PATH"
echo "saved password to '$PASSWORD_PATH'"

# Generate keys and capture both stdout and stderr
echo "generating SSV operator keys..."
if ! keys_output=$(ssvnode generate-operator-keys 2>&1); then
    echo "error: failed to generate keys"
    echo "$keys_output"
    exit 1
fi

# Extract the public and private keys
public_key=$(echo "$keys_output" | grep -o '{"pk":.*}' | jq -r '.pk')
private_key=$(echo "$keys_output" | grep -o '{"sk":.*}' | jq -r '.sk')

if [ -z "$public_key" ] || [ -z "$private_key" ]; then
    echo "error: could not parse keys from output"
    echo "$keys_output"
    exit 1
fi

# Save public key
echo "$public_key" > "$PUBLIC_KEY_PATH"
echo "saved public key to '$PUBLIC_KEY_PATH'"

# Encrypt the private key and capture output
echo "encrypting private key..."
if ! encrypt_output=$(echo "$private_key" | ssvnode generate-operator-keys -p "$PASSWORD_PATH" -o /dev/stdin 2>&1) || [ ! -f "$TEMP_ENCRYPTED_PATH" ]; then
    echo "error: failed to encrypt private key"
    echo "$encrypt_output"
    exit 1
fi

# Move the encrypted key to the final location
mv "$TEMP_ENCRYPTED_PATH" "$PRIVATE_KEY_PATH"
echo "saved encrypted private key to '$PRIVATE_KEY_PATH'"

# Display the public key
echo "generated public key:"
cat "$PUBLIC_KEY_PATH"
