#!/usr/bin/env bash
# Script for building a host with injected json data

set -o pipefail

# Default argument values
verbose=false
output_path="./result"

display_usage() {
  cat <<USAGE
Usage: $0 [options] [json_data]

Description:
  This script compiles a NixOS system by merging module options as JSON data into a base configuration.

Arguments:
  json_data
    Specify raw JSON data to merge into the base configuration. This data can also be piped into the script.

Options, required:
  -b, --base <module_name>
      Select the base configuration with the specified module name. Available: 'homestakeros'.

  -n, --name <hostname>
      Define the hostname, either for updating an existing host configuration or creating a new one.

Options, optional:
  -o, --output <output_path>
      Specify the output path for the resulting build symlinks. Default: './result'.

  -v, --verbose
      Activate verbose output mode, which displays comprehensive information for debugging purposes.

  -h, --help
      Display this help message.

Examples:
  Local, using piped input:
      echo '{"execution":{"erigon":{"enable":true}}}' | nix run .#buidl -- --name foobar --base homestakeros

  Remote, using a positional argument:
      nix run github:ponkila/homestakeros#buidl -- -n foobar -b homestakeros '{"execution":{"erigon":{"enable":true}}}'

USAGE
}

parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -b|--base)
        module_name="$2"
        shift 2 ;;
      -n|--name)
        hostname="$2"
        shift 2 ;;
      -o|--output)
        output_path="$2"
        shift 2 ;;
      -v|--verbose)
        verbose=true
        shift ;;
      -h|--help)
        display_usage
        exit 0 ;;
      *)
        # Check if argument is JSON data
        if [[ "$1" =~ ^\{.*\}$ ]]; then
          json_data="$1"
        else
          echo "error: unknown option -- '$1'"
          echo "try '--help' for more information."
          exit 1
        fi
        shift ;;
    esac
  done
  # Check that hostname has been set
  if [[ -z $hostname ]]; then
    echo "error: hostname is required."
    echo "try '--help' for more information."
    exit 1
  fi
  # Check that base configuration has been set
  if [[ -z $module_name ]]; then
    echo "error: base configuration is required."
    echo "try '--help' for more information."
    exit 1
  fi
}

create_default_nix() {
  local json_data="$1"
  local default_nix="$2"

  # Convert JSON to Nix expression using json2nix
  nix_expr=$(echo "$json_data" | nix run .#json2nix)

  # Create data.nix file
  cat > "$default_nix" << EOF
{ pkgs, config, inputs, lib, ... }:
{
  $module_name = $nix_expr;
}
EOF
}

run_nix_build() {
  local hostname="$1"
  local output_path="$2"
  local verbose="$3"

  # Default flags for the 'nix build' command
  declare -a nix_flags=(
    --accept-flake-config
    --extra-experimental-features 'nix-command flakes'
    --impure
    --no-warn-dirty
    --out-link "$output_path"
  )

  # Append '--show-trace' and '--debug' if verbose flag is true
  [[ "$verbose" = true ]] && nix_flags+=("--show-trace" "--debug")
  
  # Execute the 'nix build' command
  nix build path:.#nixosConfigurations."$hostname".config.system.build.kexecTree "${nix_flags[@]}" || exit 1
}

print_output() {
  local output_path="$1"
  local default_nix="$2"
  local verbose="$3"

  # Display injected data if verbose is true
  if [ "$verbose" = true ] && [ -f "$default_nix" ]; then
    # Replaces newlines with spaces, removes consecutive spaces and trailing space
    echo "injected data: '$(< "$default_nix" tr '\n' ' ' | tr -s ' ' | sed 's/ $//')'"
  fi

  # Print the real paths of the symlinks
  for symlink in "$output_path"/*; do
    real_path=$(readlink -f "$symlink")
    if [ "$verbose" = true ]; then 
      echo created symlink: \'"$symlink > $real_path"\'
    else
      echo "$real_path"
    fi
  done
}

main() {
  # Parse and validate command line arguments
  parse_arguments "$@"

  # Do not change, this path is also hard-coded in flake.nix
  default_nix="nixosConfigurations/$hostname/default.nix"

  # Read JSON data from stdin if it exists and is not provided as an argument
  if [ -z "$json_data" ] && ! tty -s && [ -p /dev/stdin ]; then
    json_data=$(</dev/stdin)
  fi

  # Create the host directory if it doesn't exist
  if [ ! -d "$(dirname "$default_nix")" ]; then
    mkdir -p "$(dirname "$default_nix")"
  fi

  # If JSON data is provided, create 'default.nix' from it
  [[ -n $json_data ]] && create_default_nix "$json_data" "$default_nix"

  # Format file -- This should be replaced with a hook
  nix fmt "$default_nix" > /dev/null 2>&1

  # Run the 'nix build' command
  run_nix_build "$hostname" "$output_path" $verbose

  # Display additional output, including injected data and created symlinks
  print_output "$output_path" "$default_nix" $verbose

  # Generate a JSON-formatted file containing the hostnames
  nu -c "ls nixosConfigurations | to json" > webui/nixosConfigurations/hostnames
}

main "$@"
