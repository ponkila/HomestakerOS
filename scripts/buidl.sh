#!/usr/bin/env bash
# Script for building a host with injected json data

set -o pipefail

# Default argument values
verbose=false
dry_run=false
realize=false

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
      Specify the output path for the resulting build symlinks. Default: 'webui/nixosConfigurations/<hostname>/result'.
  
  -r, --realize
      Output files instead of symlinks, aka. realize the resulting build symlinks.

  -d, --dry-run
      Do not run the 'nix build' command.

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
      -r|--realize)
        realize=true
        shift ;;
      -d|--dry-run)
        dry_run=true
        shift ;;
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

  # Set output path if not set by argument
  [[ -z $output_path ]] && output_path="webui/nixosConfigurations/${hostname}/result"
}

create_default_nix() {
  local json_data="$1"
  local default_nix="$2"

  # Convert JSON to Nix expression using json2nix
  nix_expr=$(echo "$json_data" | json2nix)

  # Create the host directory if it doesn't exist
  mkdir -p "$(dirname "$default_nix")"

  # Create default.nix file
  cat > "$default_nix" << EOF
{ pkgs, config, inputs, lib, ... }:
{
  $module_name = $nix_expr;
}
EOF

  # Run Nix formatter against the created file
  nix fmt "$default_nix" > /dev/null 2>&1
}

run_nix_build() {
  local hostname="$1"
  local output_path="$2"
  local realize="$3"
  local format="$4"
  local -a nix_flags=("${@:5}")

  # Append '--no-link' if realize flag is true, else '--out-link'
  if [[ "$realize" = true ]]; then
    nix_flags+=("--no-link")
  else
    nix_flags+=(--out-link "$output_path")
  fi

  # Append '--show-trace' and '--debug' if verbose flag is true
  [[ "$verbose" = true ]] && nix_flags+=("--show-trace" "--debug")
  
  # Execute the 'nix build' command
  nix build .#nixosConfigurations."$hostname".config.system.build."$format" "${nix_flags[@]}" || exit 1
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

  # Print the paths of the results
  if [ "$dry_run" = false ]; then
    for file_path in "$output_path"/*; do
      if [ -h "$file_path" ]; then
        real_path=$(readlink -f "$file_path")
        if [ "$verbose" = true ]; then 
          echo "created symlink: '$file_path > $real_path'"
        else
          echo "$real_path"
        fi
      else
        if [ "$verbose" = true ]; then
          echo "created file: '$file_path'"
        else
          echo "$file_path"
        fi
      fi
    done
  fi
}

get_result() {
    local hostname="$1"
    local output_path="$2"
    local format="$3"
    local -a nix_flags=("${@:4}")

    # Get the path to the Nix store
    result=$(nix eval --raw .#nixosConfigurations."$hostname".config.system.build."$format" "${nix_flags[@]}")

    # Copy the files to the output path
    mkdir -p "$output_path"

    for symlink in "$result"/*; do
      real_path=$(readlink -f "$symlink")
      new_real_path="$output_path/$(basename "$symlink")"
      cp -f "$symlink" "$new_real_path"
    done
}

create_webui_files() {
  local hostname="$1"
  local json_data="$2"
  
  default_json="webui/nixosConfigurations/$hostname/default.json"

  # Create the host directory if it doesn't exist
  mkdir -p "$(dirname "$default_json")"

  # Generate a JSON-formatted file containing the hostnames
  hostnames=$(find nixosConfigurations -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
  echo "$hostnames" | jq -R . | jq -s . > webui/nixosConfigurations/hostnames.json

  # Save the JSON data
  echo "$json_data" | jq -r "." > "$default_json"
}

detect_format() {
  local hostname="$1"
  local -a nix_flags=("${@:2}")
  
  supported_formats=("kexecTree" "isoImage")

  for format in "${supported_formats[@]}"; do
    if [[ "$(nix eval .#nixosConfigurations."$hostname".config.system.build."$format" --apply builtins.isAttrs "${nix_flags[@]}")" == true ]]; then
      echo "$format"
      return 0
    fi
  done

  echo "error: $hostname has an unsupported format." && return 1 
}

main() {
  # Parse and validate command line arguments
  parse_arguments "$@"

  # Default flags for the nix-command
  declare -a nix_flags=(
    --accept-flake-config
    --extra-experimental-features 'nix-command flakes'
    --impure
    --no-warn-dirty
  )

  # Do not change, this path is also hard-coded in flake.nix
  default_nix="nixosConfigurations/$hostname/default.nix"

  # Read JSON data from stdin if it exists and is not provided as an argument
  if [ -z "$json_data" ] && ! tty -s && [ -p /dev/stdin ]; then
    json_data=$(</dev/stdin)
  fi

  # Check if JSON data exists
  if [ -z "$json_data" ]; then
    echo "error: JSON data not provided."
    exit 1
  fi

  # Validate JSON data using jq
  if ! echo "$json_data" | jq . >/dev/null 2>&1; then
    echo "error: Invalid JSON data."
    exit 1
  fi

  # If JSON data is provided, create 'default.nix' from it
  create_default_nix "$json_data" "$default_nix"

  # Stage the changes in 'default.nix'
  git add "$default_nix"

  # Detect format, returns either 'kexecTree' or 'isoImage'
  format=$(detect_format "$hostname" "${nix_flags[@]}" || exit 1)

  # Run the 'nix build' command
  [[ $dry_run = false ]] && run_nix_build "$hostname" "$output_path" $realize "$format" "${nix_flags[@]}"

  # Create files for the webui directory
  create_webui_files "$hostname" "$json_data"

  # Copy resulting files from '/nix/store' if realize is true
  [[ $realize = true ]] && get_result "$hostname" "$output_path" "$format" "${nix_flags[@]}"

  # Display additional output, including injected data and result
  print_output "$output_path" "$default_nix" $verbose
}

main "$@"
