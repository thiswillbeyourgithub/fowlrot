# fowlrot.sh

A script that generates synchronized, time-based codes for [fowl](https://github.com/casey/fowl) connections, enabling reliable communication without systematic code exchange using pre shared secrets.

## Overview

`fowlrot.sh` (for *fowl rotator*) is a wrapper around [fowl](https://github.com/meejah/fowl/) that automatically generates synchronized codes based on time. This eliminates the need to manually share codes between connecting parties, making `fowl` usage more seamless for my use cases.

This project is in the same vein as my [wormrot.sh](https://github.com/thiswillbeyourgithub/wormrot.sh) and [knockd_rotator](https://github.com/thiswillbeyourgithub/knockd_rotator) projects and uses my [HumanReadableSeed](https://github.com/thiswillbeyourgithub/HumanReadableSeed) to generate deterministic, human-readable codes.

## Why Use This?

`fowlrot.sh` solves a small problem: when using `fowl`, you normally need to share a code between the two ends. This can be somewhat annoying, especially for frequent or scheduled connections.

With `fowlrot.sh`:
- Both parties simply run the `fowlrot.sh` command with their respective `fowl` arguments on their machines.
- The code is automatically generated based on the current time and a shared secret and modulo.
- No manual communication of codes is required.
- The code changes predictably over time, making it virtually impossible for attackers to guess.

It's especially useful for regularly establishing connections between your own devices or with trusted parties who have the same secret and modulo configured.

## Installation

1. Set up the `FOWLROT_SECRET` environment variable (must be non-empty).
2. Set up the `FOWLROT_MODULO` environment variable (default is 60 seconds; changing it increases security, but setting it too low can make synchronization difficult).
3. Make the script executable:

```bash
chmod +x fowlrot.sh
```

Note: By default, the script checks if `uvx` is installed. If found, it uses `uvx` to call the latest versions of `HumanReadableSeed` and `fowl`. If `uvx` is not installed, it will default to using `fowl` and `HumanReadableSeed` commands directly, assuming they are in your `PATH`. You might need to install them (e.g., `pip install HumanReadableSeed`, `cargo install fowl`).

## Usage

First, set up the secret environment variable on both machines:

```bash
export FOWLROT_SECRET="your-secret-here"
```

**Important**: Both `fowlrot.sh` scripts must be started at roughly the same time (within the same time window as defined by `FOWLROT_MODULO`). Starting the scripts in different time windows will cause the codes to be different and the connection to fail.

Pass any arguments intended for `fowl` directly to `fowlrot.sh`. The script will append the generated rotating code automatically.

### Server Side Example (Allowing Connection)

```bash
# Allow connection on port 7657
./fowlrot.sh --allow-connect 7657
```

### Client Side Example (Connecting)

```bash
# Connect to the server on port 7657
./fowlrot.sh --local 7657
```

### Help and version information

```bash
# Show help
./fowlrot.sh -h
# or
./fowlrot.sh --help

# Show version
./fowlrot.sh -v
# or
./fowlrot.sh --version
```

## Configuration

The script can be customized using these environment variables:

- `FOWLROT_MODULO`: Time period in seconds (default: 60, minimum: 20). Lowering it makes the code change more often, but if the two sides take too long to launch, they might miss the synchronization window.
- `FOWLROT_SECRET`: Required secret string for code generation.
- `FOWLROT_BIN`: Command to run `fowl` (default: `"uvx --quiet fowl@latest"` if `uvx` is installed, otherwise `"fowl"`).
- `FOWLROT_HRS_BIN`: Command to run `HumanReadableSeed` (default: `"uvx --quiet HumanReadableSeed@latest"` if `uvx` is installed, otherwise `"HumanReadableSeed"`).

## How It Works

The script generates synchronized codes through a series of steps:

1. **Time Synchronization**:
   - Gets the current UNIX timestamp (using UTC time) at script start.
   - Applies the `FOWLROT_MODULO` to this timestamp to determine the current time window.

2. **Period Key Generation**:
   - Creates a unique key for the current time period using the formula:
     `PERIOD_KEY = ((start_timestamp / modulo) * modulo) + secret`
   - Calculates the SHA-256 hash of the period key for enhanced security and input uniformity.

3. **Mnemonic Generation**:
   - Uses [HumanReadableSeed](https://github.com/thiswillbeyourgithub/HumanReadableSeed) to generate memorable words from the hashed period key.
   - Formats the words with hyphens (e.g., `word1-word2-word3`).

4. **Code Prefix Generation**:
   - Calculates a SHA-256 hash of the generated mnemonic words.
   - Extracts digits from this hash.
   - Computes a prefix number by taking the first few digits modulo 999 (ensuring a 1-3 digit prefix).
   - Creates the final code format: `prefix-mnemonic` (e.g., `123-word1-word2-word3`).

5. **Command Execution**:
   - The generated code is appended to the arguments provided by the user.
   - The `fowl` command (specified by `FOWLROT_BIN`) is executed with the combined arguments using `exec`, replacing the script process.

The beauty of this approach is that both sides independently generate the same code without direct communication, provided they share the same `FOWLROT_SECRET` and `FOWLROT_MODULO`, and start within the same time window.

## FAQ

### Why not use HMAC with counters instead of time synchronization?

While HMAC with counter-based approaches (similar to TOTP) could be used for code generation, the current time-based implementation offers several advantages for this use case:

- **Peer equality**: All clients are equal - there's no distinction between "server" and "client" roles needing different configurations.
- **Simplified sharing**: All participants only need to share the same secret and modulo values once.
- **Multi-client potential**: Any number of clients using the same secret/modulo can potentially connect within the same time window (though `fowl` itself is point-to-point).
- **No counter synchronization**: Avoids the complexity of keeping counters synchronized between multiple parties.
- **Predictable validity window**: The time-based approach creates natural windows when codes are valid.

The current implementation sacrifices the theoretical security properties of a pure counter-based approach for significant practical usability benefits in establishing `fowl` connections.

## Development

This tool was created with the help of [aider.chat](https://github.com/Aider-AI/aider/issues).

## License

See the LICENSE file for details.
