#!/usr/bin/env zsh

VERSION="0.1.0"
# Base timestamp calculated once at script start
BASE_TIMESTAMP=$(date -u +%s)

# Function to display help message
show_help() {
    cat << EOF
fowlrot v$VERSION - A wrapper around fowl for reliable connections with rotating codes

Usage: $0 [fowl arguments...] [-v|--version|-h|--help]

Description:
  fowlrot generates a time-based rotating code and appends it to the arguments
  passed to the 'fowl' command. It uses the same code generation mechanism
  as wormrot.

Arguments:
  [fowl arguments...]    Arguments to pass directly to the fowl command.
                         The rotating code will be appended automatically.
  -v, --version          Show version information
  -h, --help             Show this help message

Examples:
  # Server side: Allow connections on port 7657
  fowlrot --allow-connect 7657

  # Client side: Connect to the server
  fowlrot --connect 7657

Environment variables:
  FOWLROT_MODULO        Time rotation interval in seconds (min: 20, default: 60)
  FOWLROT_SECRET        Secret string for code generation (required)
  FOWLROT_BIN           Command to run fowl (default: uvx --quiet fowl@latest or fowl if uvx not found)
  FOWLROT_HRS_BIN       Command to run HumanReadableSeed (default: uvx --quiet HumanReadableSeed@latest or HumanReadableSeed if uvx not found)
EOF
}

# Check if uvx is installed
if command -v uvx &> /dev/null; then
    # uvx is available, use it for default bin values
    DEFAULT_FOWLROT_BIN="uvx --quiet fowl@latest"
    DEFAULT_FOWLROT_HRS_BIN="uvx --quiet HumanReadableSeed@latest"
else
    # uvx is not available, use plain commands
    DEFAULT_FOWLROT_BIN="fowl"
    DEFAULT_FOWLROT_HRS_BIN="HumanReadableSeed"
fi

# Environment variables with defaults
FOWLROT_MODULO=${FOWLROT_MODULO:-60}
FOWLROT_SECRET=${FOWLROT_SECRET:-""}
FOWLROT_BIN=${FOWLROT_BIN:-"$DEFAULT_FOWLROT_BIN"}
FOWLROT_HRS_BIN=${FOWLROT_HRS_BIN:-"$DEFAULT_FOWLROT_HRS_BIN"}

# Check if FOWLROT_MODULO is below 20
if [[ $FOWLROT_MODULO -lt 20 ]]; then
    echo "Error: FOWLROT_MODULO must be at least 20" >&2
    exit 1
fi

# Check if FOWLROT_SECRET is empty
if [[ -z "$FOWLROT_SECRET" ]]; then
    echo "Error: FOWLROT_SECRET cannot be empty" >&2
    exit 1
fi

# Function to generate a mnemonic based on base timestamp
generate_mnemonic() {
    # Use the global BASE_TIMESTAMP
    local CURRENT_TIMESTAMP=$BASE_TIMESTAMP
    
    # Use unmodified FOWLROT_MODULO
    local ADJ_MODULO=$FOWLROT_MODULO

    # Create PERIOD_KEY using BASE_TIMESTAMP
    local PERIOD_KEY="$(((CURRENT_TIMESTAMP / ADJ_MODULO) * ADJ_MODULO))${FOWLROT_SECRET}"

    # Calculate SHA-256 hash of the PERIOD_KEY
    local PERIOD_KEY_HASH=$(echo -n "$PERIOD_KEY" | sha256sum | awk '{print $1}')

    # Derive base MNEMONIC words
    local MNEMONIC_WORDS
    MNEMONIC_WORDS=$(eval "$FOWLROT_HRS_BIN toread $PERIOD_KEY_HASH" | tr ' ' '-')
    
    # Check if the command failed
    if [[ $? -ne 0 || -z "$MNEMONIC_WORDS" ]]; then
        echo "Error: Failed to generate mnemonic words using $FOWLROT_HRS_BIN" >&2
        echo "MNEMONIC_GENERATION_FAILED" >&2
        return 1
    fi

    # Calculate sha256sum of the mnemonic words
    local MNEMONIC_HASH=$(echo -n "$MNEMONIC_WORDS" | sha256sum | awk '{print $1}')

    # Extract integers from the hash
    local HASH_INTS=$(echo "$MNEMONIC_HASH" | tr -cd '0-9')

    # Apply modulo to cap prefix
    local PREFIX=$((${HASH_INTS:0:5} % 999))

    # Create the final mnemonic with the prefix
    echo "${PREFIX}-${MNEMONIC_WORDS}"
}

# Process command-line arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
elif [[ "$1" == "-v" || "$1" == "--version" ]]; then
    echo "fowlrot v$VERSION"
    exit 0
elif [[ $# -eq 0 ]]; then
    echo "Error: No arguments provided to fowl." >&2
    show_help
    exit 1
fi

# Generate the mnemonic code
MNEMONIC=$(generate_mnemonic)
MNEMONIC_EXIT_CODE=$?

# Check if generate_mnemonic failed and exit immediately
if [[ $MNEMONIC_EXIT_CODE -ne 0 ]]; then
    echo "Error: Mnemonic generation failed with exit code $MNEMONIC_EXIT_CODE" >&2
    echo "Aborting operation." >&2
    exit 1
fi

# Check if we got a valid mnemonic
if [[ -z "$MNEMONIC" ]]; then
    echo "Error: Failed to generate a valid mnemonic" >&2
    exit 1
fi

# Prepare the command arguments
# Use "$@" to preserve arguments exactly as passed, including spaces
FOWL_ARGS=("$@")

# Execute the fowl command with the provided arguments and the generated mnemonic
echo "Using code: $MNEMONIC" >&2
echo "Executing: $FOWLROT_BIN ${FOWL_ARGS[@]} $MNEMONIC" >&2

# Split FOWLROT_BIN into command and arguments array
local -a FOWL_CMD_PARTS
FOWL_CMD_PARTS=(${(z)FOWLROT_BIN}) # zsh specific word splitting

# Use exec to replace the script process with the fowl process
# This ensures signals (like Ctrl+C) are handled correctly by fowl
exec "${FOWL_CMD_PARTS[@]}" "${FOWL_ARGS[@]}" "$MNEMONIC"

# The script will exit with the exit code of the fowl command
# or earlier if exec fails. Check exec failure just in case.
exec_exit_code=$?
if [[ $exec_exit_code -ne 0 ]]; then
    # Use the array in the error message for clarity
    echo "Error: Failed to execute command: ${FOWL_CMD_PARTS[@]}" >&2
    exit $exec_exit_code
fi
