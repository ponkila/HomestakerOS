# 4. Options Reference

This document provides a comprehensive reference for all configuration options available in HomestakerOS.
These options can be set through the web interface when creating or editing a node.

## Table of Contents

- [Execution Clients](#execution-clients)
  - [Erigon](#erigon)
  - [Geth](#geth)
  - [Nethermind](#nethermind)
  - [Besu](#besu)
- [Consensus Clients](#consensus-clients)
  - [Lighthouse](#lighthouse)
  - [Prysm](#prysm)
  - [Nimbus](#nimbus)
  - [Teku](#teku)
- [Add-ons](#add-ons)
  - [MEV-Boost](#mev-boost)
  - [SSV-Node](#ssv-node)
- [Localization](#localization)
- [Mounts](#mounts)
- [SSH](#ssh)
- [VPN](#vpn)

## Execution Clients

> **Note:** You should choose exactly one execution client to pair with your consensus client.

Execution layer client options (formerly known as Ethereum 1.0 clients).

### Erigon

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | Boolean | `false` | Whether to enable Erigon. |
| `dataDir` | Path | `"/mnt/erigon"` | Data directory for the blockchain. |
| `endpoint` | String | `"http://127.0.0.1:8551"` | HTTP-RPC server listening interface of engine API. |
| `jwtSecretFile` | String | `"/mnt/secrets/jwt.hex"` | Path to the token that ensures safe connection between CL and EL. |
| `extraOptions` | List of Strings | `[]` | Additional command-line arguments.
Example: `["--some-extra-option=value"]` |

### Geth

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | Boolean | `false` | Whether to enable Geth. |
| `dataDir` | Path | `"/mnt/geth"` | Data directory for the blockchain. |
| `endpoint` | String | `"http://127.0.0.1:8551"` | HTTP-RPC server listening interface of engine API. |
| `jwtSecretFile` | String | `"/mnt/secrets/jwt.hex"` | Path to the token that ensures safe connection between CL and EL. |
| `extraOptions` | List of Strings | `[]` | Additional command-line arguments.
Example: `["--some-extra-option=value"]` |

### Nethermind

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | Boolean | `false` | Whether to enable Nethermind. |
| `dataDir` | Path | `"/mnt/nethermind"` | Data directory for the blockchain. |
| `endpoint` | String | `"http://127.0.0.1:8551"` | HTTP-RPC server listening interface of engine API. |
| `jwtSecretFile` | String | `"/mnt/secrets/jwt.hex"` | Path to the token that ensures safe connection between CL and EL. |
| `extraOptions` | List of Strings | `[]` | Additional command-line arguments.
Example: `["--some-extra-option=value"]` |

### Besu

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | Boolean | `false` | Whether to enable Besu. |
| `dataDir` | Path | `"/mnt/besu"` | Data directory for the blockchain. |
| `endpoint` | String | `"http://127.0.0.1:8551"` | HTTP-RPC server listening interface of engine API. |
| `jwtSecretFile` | String | `"/mnt/secrets/jwt.hex"` | Path to the token that ensures safe connection between CL and EL. |
| `extraOptions` | List of Strings | `[]` | Additional command-line arguments.
Example: `["--some-extra-option=value"]` |

## Consensus Clients

> **Note:** You should choose exactly one consensus client to pair with your execution client.

Consensus layer client options (formerly known as Ethereum 2.0 clients).

### Lighthouse

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | Boolean | `false` | Whether to enable Lighthouse. |
| `dataDir` | Path | `"/mnt/lighthouse"` | Data directory for the blockchain. |
| `endpoint` | String | `"http://127.0.0.1:5052"` | HTTP server listening interface. |
| `execEndpoint` | String | `"http://127.0.0.1:8551"` | Server endpoint for an execution layer JWT-authenticated HTTP JSON-RPC connection. |
| `jwtSecretFile` | Path | `"/mnt/secrets/jwt.hex"` | Path to the token that ensures safe connection between CL and EL. |
| `extraOptions` | List of Strings | `[]` | Additional command-line arguments.
Example: `["--some-extra-option=value"]` |
| `slasher.enable` | Boolean | `false` | Whether to enable slasher. |
| `slasher.historyLength` | Integer | `4096` | Number of epochs to store. |
| `slasher.maxDatabaseSize` | Integer | `256` | Maximum size of the slasher database in gigabytes. |

### Prysm

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | Boolean | `false` | Whether to enable Prysm. |
| `dataDir` | Path | `"/mnt/prysm"` | Data directory for the blockchain. |
| `endpoint` | String | `"http://127.0.0.1:3500"` | JSON-HTTP server listening interface. |
| `execEndpoint` | String | `"http://127.0.0.1:8551"` | Server endpoint for an execution layer JWT-authenticated HTTP JSON-RPC connection. |
| `jwtSecretFile` | Path | `"/mnt/secrets/jwt.hex"` | Path to the token that ensures safe connection between CL and EL. |
| `extraOptions` | List of Strings | `[]` | Additional command-line arguments.
Example: `["--some-extra-option=value"]` |
| `slasher.enable` | Boolean | `false` | Whether to enable historical slasher. |

### Nimbus

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | Boolean | `false` | Whether to enable Nimbus. |
| `dataDir` | Path | `"/mnt/nimbus"` | Data directory for the blockchain. |
| `endpoint` | String | `"http://127.0.0.1:5052"` | JSON-HTTP server listening interface. |
| `execEndpoint` | String | `"http://127.0.0.1:8551"` | Server endpoint for an execution layer JWT-authenticated HTTP JSON-RPC connection. |
| `jwtSecretFile` | Path | `"/mnt/secrets/jwt.hex"` | Path to the token that ensures safe connection between CL and EL. |
| `extraOptions` | List of Strings | `[]` | Additional command-line arguments.
Example: `["--some-extra-option=value"]` |

### Teku

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | Boolean | `false` | Whether to enable Teku. |
| `dataDir` | Path | `"/mnt/teku"` | Data directory for the blockchain. |
| `endpoint` | String | `"http://127.0.0.1:5051"` | JSON-HTTP server listening interface. |
| `execEndpoint` | String | `"http://127.0.0.1:8551"` | Server endpoint for an execution layer JWT-authenticated HTTP JSON-RPC connection. |
| `jwtSecretFile` | Path | `"/mnt/secrets/jwt.hex"` | Path to the token that ensures safe connection between CL and EL. |
| `extraOptions` | List of Strings | `[]` | Additional command-line arguments.
Example: `["--some-extra-option=value"]` |

## Add-ons

Additional services and tools to enhance your staking setup.

### MEV-Boost

> **Note:** MEV-Boost allows validators to access a competitive block-building market to maximize rewards.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | Boolean | `false` | Whether to enable MEV-Boost. |
| `endpoint` | String | `"http://127.0.0.1:18550"` | Listening interface for the MEV-Boost server. |
| `extraOptions` | List of Strings | `[]` | Additional command-line arguments.
Example: `["--some-extra-option=value"]` |

### SSV-Node

> **Note:** SSV-Node enables distributed validator technology for increased reliability and security.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `dataDir` | Path | `"/mnt/addons/ssv"` | Path to a persistent directory to store the node's database and keys.
Expected files: ssv_operator_key, ssv_operator_key.pub, and password.
Keys will be generated automatically if missing. |
| `extraOptions` | List of Strings | `[]` | Additional command-line arguments.
Example: `["--some-extra-option=value"]` |

## Localization

Settings related to system localization.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `hostname` | String | `"homestaker"` | The name of the machine.
Must contain only alphanumeric characters, hyphens, or underscores, with a length between 1-63 characters. |
| `timezone` | String | `"UTC"` | The time zone used when displaying times and dates.
Example: `"America/New_York"` |

## Mounts

Configuration for system mounts.
Define storage locations as systemd mount units.

> **Important:** Properly configured mounts are crucial for data persistence, as HomestakerOS runs entirely in RAM.

Each mount entry has the following options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `before` | List of Strings | `[]` | If the specified units are started at the same time as this unit, delay them until this unit has started. |
| `description` | String | `"storage device"` | Description of this unit used in systemd messages and progress indicators. |
| `enable` | Boolean | `false` | Whether to enable this mount. |
| `options` | String | `"noatime"` | Options used to mount the file system; strings concatenated with ",". |
| `type` | String | `"auto"` | File system type.
Example: `"btrfs"` |
| `wantedBy` | List of Strings | `["multi-user.target"]` | Units that want (i.e. depend on) this unit. |
| `what` | String | (Required) | Absolute path of device node, file or other resource.
Example: `"/dev/disk/by-label/homestaker"` |
| `where` | String | (Required) | Absolute path of a directory of the mount point.
Will be created if it doesn't exist.
Example: `"/mnt/erigon"` |

## SSH

SSH server configuration for secure remote access to your node.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `authorizedKeys` | List of Strings | `[]` | A list of public SSH keys to be added to the user's authorized keys. |
| `privateKeyFile` | Path | `"/mnt/secrets/ssh/id_ed25519"` | Path to the Ed25519 SSH host key.
If absent, the key will be generated automatically. |

## VPN

Virtual Private Network configurations for secure communications.

### WireGuard

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | Boolean | `false` | Whether to enable WireGuard. |
| `configFile` | Path | `"/mnt/secrets/wg0.conf"` | A file path for the wg-quick configuration. |
