# Adding Organizations Dynamically to the Test Network

This folder contains a dynamic script to add any organization to the Fabric test network. Unlike the `addOrg3` or `addOrg4` folders which are hardcoded for specific organizations, this script allows you to specify the organization number as a parameter.

## Prerequisites

You must first bring up the test network and create a channel:

```bash
cd test-network
./network.sh up createChannel
```

## Usage

```bash
cd addOrg
./addOrg.sh <mode> -org <org_number> [options]
```

### Modes

- `up` - Add the organization to the network
- `down` - Bring down the entire network
- `generate` - Generate certificates and organization definition only

### Required Parameters

- `-org <number>` - Organization number (e.g., 5 for Org5, 6 for Org6, etc.)

### Optional Parameters

- `-c <channel>` - Channel name (default: "mychannel")
- `-ca` - Use Fabric CA instead of cryptogen
- `-s couchdb` - Use CouchDB as the state database
- `-t <timeout>` - CLI timeout in seconds (default: 10)
- `-d <delay>` - CLI delay in seconds (default: 3)
- `-verbose` - Enable verbose mode

## Examples

### Add Org5 to the network
```bash
./addOrg.sh up -org 5
```

### Add Org6 with CouchDB
```bash
./addOrg.sh up -org 6 -s couchdb
```

### Add Org7 to a custom channel
```bash
./addOrg.sh up -org 7 -c mycustomchannel
```

### Generate certificates only for Org8
```bash
./addOrg.sh generate -org 8
```

### Add Org5 using Fabric CA
```bash
./addOrg.sh up -org 5 -ca
```

## Port Allocation

The script automatically calculates ports based on the organization number:

| Org | Peer Port | CA Port | CouchDB Port | Chaincode Port |
|-----|-----------|---------|--------------|----------------|
| 1   | 7051      | 7054    | 5984         | 7052           |
| 2   | 9051      | 8054    | 7984         | 9052           |
| 3   | 11051     | 11054   | 9984         | 11052          |
| 4   | 11052     | 11055   | 9984         | 11053          |
| 5+  | 12051+    | 12054+  | 12084+       | 12052+         |

For organizations 5 and above, ports are calculated as:
- Base = 12000 + (org_num - 5) * 1000
- Peer Port = Base + 51
- CA Port = Base + 54
- CouchDB Port = Base + 84
- Chaincode Port = Base + 52

## What the Script Does

1. **Generates crypto material** - Using cryptogen or Fabric CA
2. **Generates organization definition** - Creates configtx.yaml and org JSON
3. **Creates Docker Compose files** - Dynamically generates compose files for the peer
4. **Brings up peer container** - Starts the peer node
5. **Updates channel configuration** - Adds the org to the channel
6. **Joins peer to channel** - Joins the new peer to the channel
7. **Sets anchor peer** - Configures the anchor peer for the organization

## Generated Files

The script generates files in the following locations:

- `organizations/peerOrganizations/org<N>.example.com/` - Crypto material
- `organizations/peerOrganizations/org<N>.example.com/org<N>.json` - Org definition
- `addOrg/compose/compose-org<N>.yaml` - Docker compose files
- `addOrg/org<N>-crypto.yaml` - Cryptogen config
- `addOrg/configtx.yaml` - Organization configtx

## Troubleshooting

### Channel not found
Make sure to run `./network.sh up createChannel` first.

### Port already in use
Check if the calculated ports conflict with other services. You may need to stop containers using those ports.

### Peer fails to join
Wait a few seconds and retry. The orderer might need time to process the config update.
