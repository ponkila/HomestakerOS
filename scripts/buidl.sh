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
      Select the base configuration. Available: 'homestakeros'.

  -f, --format <output_format>
      Select the output format. Available: 'kexecTree', 'isoImage'.

  -n, --name <hostname>
      Define the hostname, either for updating an existing host configuration or creating a new one.

  -s, --system <system>
      Select the system architecture. Available: 'x86_64-linux', 'aarch64-linux'.

Options, optional:

  -o, --output <output_path>
      Specify the output path for the result. Default: 'webui/public/nixosConfigurations/<hostname>/result'.
  
  -r, --realize
      Output files instead of symlinks.

  -d, --dry-run
      Do not run the 'nix build' command.

  -v, --verbose
      Activate verbose output mode.

  -h, --help
      Display this help message.

Examples:

  Local, using piped input:
      echo '{"execution":{"erigon":{"enable":true}}}' | nix run .#buidl -- --name foobar --base homestakeros --system x86_64-linux --format isoImage

  Remote, using a positional argument:
      nix run github:ponkila/homestakeros#buidl -- -n foobar -b homestakeros -s x86_64-linux -f isoImage '{"execution":{"erigon":{"enable":true}}}'

USAGE
}

parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -b|--base)
        module_name="$2"
        shift 2 ;;
      -f|--format)
        format="$2"
        shift 2 ;;
      -n|--name)
        hostname="$2"
        shift 2 ;;
      -s|--system)
        system="$2"
        shift 2;;
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
  elif [[ "$module_name" != "homestakeros" ]]; then
    echo "error: unknown base configuration -- '$module_name'."
    echo "try '--help' for more information."
    exit 1
  fi

  # Check that format has been set
  if [[ -z $format ]]; then
    echo "error: output format is required."
    echo "try '--help' for more information."
    exit 1
  elif [[ "$format" != "isoImage" && "$format" != "kexecTree" ]]; then
    echo "error: unknown output format -- '$format'."
    echo "try '--help' for more information."
    exit 1
  fi

  # Check that system has been set
  if [[ -z $system ]]; then
    echo "error: system architecture is required."
    echo "try '--help' for more information."
    exit 1
  elif [[ "$system" != "aarch64-linux" && "$system" != "x86_64-linux" ]]; then
    echo "error: unknown system architecture -- '$system'."
    echo "try '--help' for more information."
    exit 1
  fi

  # Set output path if not set by argument
  [[ -z $output_path ]] && output_path="webui/public/nixosConfigurations/${hostname}/result"
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
  local build_path="$1"
  local output_path="$2"
  local realize="$3"
  local -a nix_flags=("${@:4}")

  # Append '--no-link' if realize flag is true, else '--out-link'
  if [[ "$realize" = true ]]; then
    nix_flags+=("--no-link")
  else
    nix_flags+=(--out-link "$output_path")
  fi

  # Append '--show-trace' and '--debug' if verbose flag is true
  [[ "$verbose" = true ]] && nix_flags+=("--show-trace" "--debug")

  # Execute the 'nix build' command
  nix build .#"$build_path" "${nix_flags[@]}" || exit 1
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
    local build_path="$1"
    local output_path="$2"
    local -a nix_flags=("${@:3}")

    # Get the path to the Nix store
    result=$(nix eval --raw .#"$build_path" "${nix_flags[@]}")

    # Copy the files to the output path
    mkdir -p "$output_path"

    for symlink in "$result"/*; do
      real_path="$output_path/$(basename "$symlink")"
      cp -f "$symlink" "$real_path"
    done
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

  # Combine arguments to a nixosConfiguration build path
  build_path="nixosConfigurations.${hostname}-${system}-${format}.config.system.build.${format}"

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

  # Run the 'nix build' command
  [[ $dry_run = false ]] && run_nix_build "$build_path" "$output_path" $realize "${nix_flags[@]}"

  # Create the JSON files for the webui directory
  update-json

  # Copy resulting files from '/nix/store' if realize is true
  [[ $realize = true ]] && get_result "$build_path" "$output_path" "${nix_flags[@]}"

  # Display additional output, including injected data and result
  print_output "$output_path" "$default_nix" $verbose
}

main "$@"
