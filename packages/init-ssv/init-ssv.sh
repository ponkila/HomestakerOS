#!/usr/bin/env bash
# Script to generate SSV operator keys with a password

# Define default file paths
PRIVATE_KEY_PATH="${PRIVATE_KEY_PATH:-ssv_operator_key}"
PUBLIC_KEY_PATH="${PUBLIC_KEY_PATH:-ssv_operator_key.pub}"
PASSWORD_PATH="${PASSWORD_PATH:-password}"
TEMP_ENCRYPTED_PATH="encrypted_private_key.json"

# Display usage information
display_usage() {
  cat <<USAGE
Usage: init-ssv [OPTIONS...] <PASSWORD>

Description:
  Generate SSV operator keys with password encryption.

Arguments:
  PASSWORD
    Password to encrypt the private key (required).

Options:
  -p, --private-key FILE     Set private key output file (default: $PRIVATE_KEY_PATH)
  -b, --public-key FILE      Set public key output file (default: $PUBLIC_KEY_PATH)
  -w, --password-path FILE   Set password file path (default: $PASSWORD_PATH)
  -h, --help                 Show this help message
USAGE
  exit 0
}

# Main function
main() {
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--private-key)
        PRIVATE_KEY_PATH="$2"
        shift 2
        ;;
      -b|--public-key)
        PUBLIC_KEY_PATH="$2"
        shift 2
        ;;
      -w|--password-file)
        PASSWORD_PATH="$2"
        shift 2
        ;;
      -h|--help)
        display_usage
        ;;
      -*)
        echo "error: unknown option: $1"
        display_usage
        ;;
      *)
        # This should be the password
        if [[ -z "$PASSWORD" ]]; then
          PASSWORD="$1"
          shift
        else
          echo "error: only one argument is allowed"
          display_usage
        fi
        ;;
    esac
  done

  # Validate required arguments
  if [[ -z "$PASSWORD" ]]; then
    echo "error: password must be provided"
    display_usage
  fi

  # Ensure output directories exist
  mkdir -p "$(dirname "$PRIVATE_KEY_PATH")"
  mkdir -p "$(dirname "$PUBLIC_KEY_PATH")"
  mkdir -p "$(dirname "$PASSWORD_PATH")"

  # Save password to file
  echo "$PASSWORD" > "$PASSWORD_PATH"
  echo "saved password to '$PASSWORD_PATH'"

  # Generate keys and capture both stdout and stderr
  echo "generating ssv operator keys..."
  if ! keys_output=$(ssvnode generate-operator-keys 2>&1); then
      echo "error: failed to generate keys"
      echo "$keys_output"
      exit 1
  fi

  # Extract the public and private keys
  public_key=$(echo "$keys_output" | grep -o '{"pk":.*}' | jq -r '.pk')
  private_key=$(echo "$keys_output" | grep -o '{"sk":.*}' | jq -r '.sk')

  if [[ -z "$public_key" ]] || [[ -z "$private_key" ]]; then
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
}

# Run the main function
main "$@"
