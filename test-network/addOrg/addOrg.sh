#!/usr/bin/env bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This script extends the Hyperledger Fabric test network by adding
# a new organization to the network dynamically
#

# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
export PATH=${PWD}/../../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}/../../config
export VERBOSE=false

. ../scripts/utils.sh

: ${CONTAINER_CLI:="docker"}
if command -v ${CONTAINER_CLI}-compose > /dev/null 2>&1; then
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
else
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI} compose"}
fi
infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  addOrg.sh up|down|generate -org <org number> [-c <channel name>] [-t <timeout>] [-d <delay>] [-s <dbtype>]"
  echo "  addOrg.sh -h|--help (print this message)"
  echo
  echo "    <mode> - one of 'up', 'down', or 'generate'"
  echo "      - 'up' - add the organization to the sample network. You need to bring up the test network and create a channel first."
  echo "      - 'down' - bring down the test network and organization nodes"
  echo "      - 'generate' - generate required certificates and org definition"
  echo
  echo "    -org <org number> - organization number (e.g., 5 for Org5) - REQUIRED"
  echo "    -c <channel name> - test network channel name (defaults to \"mychannel\")"
  echo "    -ca <use CA> - Use a CA to generate the crypto material"
  echo "    -t <timeout> - CLI timeout duration in seconds (defaults to 10)"
  echo "    -d <delay> - delay duration in seconds (defaults to 3)"
  echo "    -s <dbtype> - the database backend to use: goleveldb (default) or couchdb"
  echo "    -verbose - verbose mode"
  echo
  echo "Examples:"
  echo "  addOrg.sh generate -org 5"
  echo "  addOrg.sh up -org 5"
  echo "  addOrg.sh up -org 5 -c mychannel -s couchdb"
  echo "  addOrg.sh down"
}

# Calculate ports based on org number
# Org1: 7051, Org2: 9051, Org3: 11051, Org4: 11052, Org5+: dynamic
function calculatePorts() {
  if [ $ORG_NUM -eq 1 ]; then
    PEER_PORT=7051
    CA_PORT=7054
    COUCH_PORT=5984
    CHAINCODE_PORT=7052
  elif [ $ORG_NUM -eq 2 ]; then
    PEER_PORT=9051
    CA_PORT=8054
    COUCH_PORT=7984
    CHAINCODE_PORT=9052
  elif [ $ORG_NUM -eq 3 ]; then
    PEER_PORT=11051
    CA_PORT=11054
    COUCH_PORT=9984
    CHAINCODE_PORT=11052
  elif [ $ORG_NUM -eq 4 ]; then
    PEER_PORT=11052
    CA_PORT=11055
    COUCH_PORT=9984
    CHAINCODE_PORT=11053
  else
    # For Org5+, calculate based on org number
    # Base port: 12000 + (org_num - 5) * 1000
    BASE=$((12000 + (ORG_NUM - 5) * 1000))
    PEER_PORT=$((BASE + 51))
    CA_PORT=$((BASE + 54))
    COUCH_PORT=$((BASE + 84))
    CHAINCODE_PORT=$((BASE + 52))
  fi
  
  export PEER_PORT CA_PORT COUCH_PORT CHAINCODE_PORT
  infoln "Org${ORG_NUM} Ports - Peer: ${PEER_PORT}, CA: ${CA_PORT}, CouchDB: ${COUCH_PORT}, Chaincode: ${CHAINCODE_PORT}"
}

# Generate crypto material using cryptogen
function generateOrgCrypto() {
  which cryptogen
  if [ "$?" -ne 0 ]; then
    fatalln "cryptogen tool not found. exiting"
  fi
  
  infoln "Generating certificates using cryptogen tool"
  infoln "Creating Org${ORG_NUM} Identities"

  # Generate crypto config file dynamically
  cat > org${ORG_NUM}-crypto.yaml <<EOF
# Copyright IBM Corp. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

PeerOrgs:
  - Name: Org${ORG_NUM}
    Domain: org${ORG_NUM}.example.com
    EnableNodeOUs: true
    Template:
      Count: 1
      SANS:
        - localhost
    Users:
      Count: 1
EOF

  set -x
  cryptogen generate --config=org${ORG_NUM}-crypto.yaml --output="../organizations"
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate certificates..."
  fi
}

# Generate crypto material using Fabric CA
function generateOrgCryptoCA() {
  fabric-ca-client version > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    fatalln "fabric-ca-client binary not found.."
  fi

  infoln "Generating certificates using Fabric CA"
  
  # Generate CA compose file
  generateCAComposeFile
  
  ${CONTAINER_CLI_COMPOSE} -f compose/compose-ca-org${ORG_NUM}.yaml -f compose/${CONTAINER_CLI}/docker-compose-ca-org${ORG_NUM}.yaml up -d 2>&1

  sleep 10

  infoln "Creating Org${ORG_NUM} Identities"
  createOrgCA
}

function createOrgCA() {
  infoln "Enrolling the CA admin"
  mkdir -p ../organizations/peerOrganizations/org${ORG_NUM}.example.com/

  export FABRIC_CA_CLIENT_HOME=${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:${CA_PORT} --caname ca-org${ORG_NUM} --tls.certfiles "${PWD}/fabric-ca/org${ORG_NUM}/tls-cert.pem"
  { set +x; } 2>/dev/null

  echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-${CA_PORT}-ca-org${ORG_NUM}.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-${CA_PORT}-ca-org${ORG_NUM}.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-${CA_PORT}-ca-org${ORG_NUM}.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-${CA_PORT}-ca-org${ORG_NUM}.pem
    OrganizationalUnitIdentifier: orderer" > "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/msp/config.yaml"

  infoln "Registering peer0"
  set -x
  fabric-ca-client register --caname ca-org${ORG_NUM} --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles "${PWD}/fabric-ca/org${ORG_NUM}/tls-cert.pem"
  { set +x; } 2>/dev/null

  infoln "Registering user"
  set -x
  fabric-ca-client register --caname ca-org${ORG_NUM} --id.name user1 --id.secret user1pw --id.type client --tls.certfiles "${PWD}/fabric-ca/org${ORG_NUM}/tls-cert.pem"
  { set +x; } 2>/dev/null

  infoln "Registering the org admin"
  set -x
  fabric-ca-client register --caname ca-org${ORG_NUM} --id.name org${ORG_NUM}admin --id.secret org${ORG_NUM}adminpw --id.type admin --tls.certfiles "${PWD}/fabric-ca/org${ORG_NUM}/tls-cert.pem"
  { set +x; } 2>/dev/null

  infoln "Generating the peer0 msp"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:${CA_PORT} --caname ca-org${ORG_NUM} -M "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/msp" --tls.certfiles "${PWD}/fabric-ca/org${ORG_NUM}/tls-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/msp/config.yaml" "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/msp/config.yaml"

  infoln "Generating the peer0-tls certificates"
  set -x
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:${CA_PORT} --caname ca-org${ORG_NUM} -M "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/tls" --enrollment.profile tls --csr.hosts peer0.org${ORG_NUM}.example.com --csr.hosts localhost --tls.certfiles "${PWD}/fabric-ca/org${ORG_NUM}/tls-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/tls/tlscacerts/"* "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/tls/ca.crt"
  cp "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/tls/signcerts/"* "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/tls/server.crt"
  cp "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/tls/keystore/"* "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/tls/server.key"

  mkdir -p "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/msp/tlscacerts"
  cp "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/tls/tlscacerts/"* "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/msp/tlscacerts/ca.crt"

  mkdir -p "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/tlsca"
  cp "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/tls/tlscacerts/"* "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/tlsca/tlsca.org${ORG_NUM}.example.com-cert.pem"

  mkdir -p "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/ca"
  cp "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/msp/cacerts/"* "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/ca/ca.org${ORG_NUM}.example.com-cert.pem"

  infoln "Generating the user msp"
  set -x
  fabric-ca-client enroll -u https://user1:user1pw@localhost:${CA_PORT} --caname ca-org${ORG_NUM} -M "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/users/User1@org${ORG_NUM}.example.com/msp" --tls.certfiles "${PWD}/fabric-ca/org${ORG_NUM}/tls-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/msp/config.yaml" "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/users/User1@org${ORG_NUM}.example.com/msp/config.yaml"

  infoln "Generating the org admin msp"
  set -x
  fabric-ca-client enroll -u https://org${ORG_NUM}admin:org${ORG_NUM}adminpw@localhost:${CA_PORT} --caname ca-org${ORG_NUM} -M "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/users/Admin@org${ORG_NUM}.example.com/msp" --tls.certfiles "${PWD}/fabric-ca/org${ORG_NUM}/tls-cert.pem"
  { set +x; } 2>/dev/null

  cp "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/msp/config.yaml" "${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/users/Admin@org${ORG_NUM}.example.com/msp/config.yaml"
}

# Generate organization definition
function generateOrgDefinition() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatalln "configtxgen tool not found. exiting"
  fi
  
  infoln "Generating Org${ORG_NUM} organization definition"
  
  # Generate configtx.yaml dynamically
  cat > configtx.yaml <<EOF
# Copyright IBM Corp. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

Organizations:
    - &Org${ORG_NUM}
        Name: Org${ORG_NUM}MSP
        ID: Org${ORG_NUM}MSP
        MSPDir: ../organizations/peerOrganizations/org${ORG_NUM}.example.com/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('Org${ORG_NUM}MSP.admin', 'Org${ORG_NUM}MSP.peer', 'Org${ORG_NUM}MSP.client')"
            Writers:
                Type: Signature
                Rule: "OR('Org${ORG_NUM}MSP.admin', 'Org${ORG_NUM}MSP.client')"
            Admins:
                Type: Signature
                Rule: "OR('Org${ORG_NUM}MSP.admin')"
            Endorsement:
                Type: Signature
                Rule: "OR('Org${ORG_NUM}MSP.peer')"
EOF

  export FABRIC_CFG_PATH=$PWD
  set -x
  configtxgen -printOrg Org${ORG_NUM}MSP > ../organizations/peerOrganizations/org${ORG_NUM}.example.com/org${ORG_NUM}.json
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate Org${ORG_NUM} organization definition..."
  fi
}

# Generate compose files dynamically
function generateComposeFiles() {
  infoln "Generating Docker Compose files for Org${ORG_NUM}"
  
  # Generate main compose file
  cat > compose/compose-org${ORG_NUM}.yaml <<EOF
# Copyright IBM Corp. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

volumes:
  peer0.org${ORG_NUM}.example.com:

networks:
  test:
    name: fabric_test

services:
  peer0.org${ORG_NUM}.example.com:
    container_name: peer0.org${ORG_NUM}.example.com
    image: hyperledger/fabric-peer:latest
    labels:
      service: hyperledger-fabric
    environment:
      - FABRIC_CFG_PATH=/etc/hyperledger/peercfg
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_PROFILE_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
      - CORE_PEER_ID=peer0.org${ORG_NUM}.example.com
      - CORE_PEER_ADDRESS=peer0.org${ORG_NUM}.example.com:${PEER_PORT}
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp
      - CORE_PEER_LISTENADDRESS=0.0.0.0:${PEER_PORT}
      - CORE_PEER_CHAINCODEADDRESS=peer0.org${ORG_NUM}.example.com:${CHAINCODE_PORT}
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:${CHAINCODE_PORT}
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org${ORG_NUM}.example.com:${PEER_PORT}
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org${ORG_NUM}.example.com:${PEER_PORT}
      - CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP
      - CORE_METRICS_PROVIDER=prometheus
      - CHAINCODE_AS_A_SERVICE_BUILDER_CONFIG={"peername":"peer0org${ORG_NUM}"}
      - CORE_CHAINCODE_EXECUTETIMEOUT=300s      
    volumes:
        - ../../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com:/etc/hyperledger/fabric        
        - peer0.org${ORG_NUM}.example.com:/var/hyperledger/production
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    ports:
      - ${PEER_PORT}:${PEER_PORT}
    networks:
      - test
EOF

  # Generate docker-specific compose file
  cat > compose/${CONTAINER_CLI}/docker-compose-org${ORG_NUM}.yaml <<EOF
# Copyright IBM Corp. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

networks:
  test:
    name: fabric_test

services:
  peer0.org${ORG_NUM}.example.com:
    container_name: peer0.org${ORG_NUM}.example.com
    image: hyperledger/fabric-peer:latest
    labels:
      service: hyperledger-fabric
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=fabric_test
    volumes:
      - ./docker/peercfg:/etc/hyperledger/peercfg
      - \${DOCKER_SOCK}:/host/var/run/docker.sock
EOF

  # Generate CouchDB compose file
  cat > compose/compose-couch-org${ORG_NUM}.yaml <<EOF
# Copyright IBM Corp. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

networks:
  test:
    name: fabric_test

services:
  couchdb${ORG_NUM}:
    container_name: couchdb${ORG_NUM}
    image: couchdb:3.4.2
    labels:
      service: hyperledger-fabric
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - "${COUCH_PORT}:5984"
    networks:
      - test

  peer0.org${ORG_NUM}.example.com:
    environment:
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb${ORG_NUM}:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw
    depends_on:
      - couchdb${ORG_NUM}
    networks:
      - test
EOF

  # Generate docker-specific couch compose file
  cat > compose/${CONTAINER_CLI}/docker-compose-couch-org${ORG_NUM}.yaml <<EOF
# Copyright IBM Corp. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

networks:
  test:
    name: fabric_test

services:
  couchdb${ORG_NUM}:
    container_name: couchdb${ORG_NUM}
    networks:
      - test

  peer0.org${ORG_NUM}.example.com:
    networks:
      - test
EOF
}

# Generate CA compose files
function generateCAComposeFile() {
  mkdir -p fabric-ca/org${ORG_NUM}
  
  cat > compose/compose-ca-org${ORG_NUM}.yaml <<EOF
# Copyright IBM Corp. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

networks:
  test:
    name: fabric_test

services:
  ca_org${ORG_NUM}:
    image: hyperledger/fabric-ca:latest
    labels:
      service: hyperledger-fabric
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-org${ORG_NUM}
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_PORT=${CA_PORT}
    ports:
      - "${CA_PORT}:${CA_PORT}"
    command: sh -c 'fabric-ca-server start -b admin:adminpw -d'
    volumes:
      - ../fabric-ca/org${ORG_NUM}:/etc/hyperledger/fabric-ca-server
    container_name: ca_org${ORG_NUM}
    networks:
      - test
EOF

  cat > compose/${CONTAINER_CLI}/docker-compose-ca-org${ORG_NUM}.yaml <<EOF
# Copyright IBM Corp. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

networks:
  test:
    name: fabric_test

services:
  ca_org${ORG_NUM}:
    container_name: ca_org${ORG_NUM}
    networks:
      - test
EOF
}

# Generate CCP files
function generateCCP() {
  infoln "Generating CCP files for Org${ORG_NUM}"
  
  PEERPEM=../organizations/peerOrganizations/org${ORG_NUM}.example.com/tlsca/tlsca.org${ORG_NUM}.example.com-cert.pem
  CAPEM=../organizations/peerOrganizations/org${ORG_NUM}.example.com/ca/ca.org${ORG_NUM}.example.com-cert.pem

  PP=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' $PEERPEM)
  CP=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' $CAPEM)

  cat > ../organizations/peerOrganizations/org${ORG_NUM}.example.com/connection-org${ORG_NUM}.json <<EOF
{
    "name": "test-network-org${ORG_NUM}",
    "version": "1.0.0",
    "client": {
        "organization": "Org${ORG_NUM}",
        "connection": {
            "timeout": {
                "peer": {
                    "endorser": "300"
                }
            }
        }
    },
    "organizations": {
        "Org${ORG_NUM}": {
            "mspid": "Org${ORG_NUM}MSP",
            "peers": [
                "peer0.org${ORG_NUM}.example.com"
            ],
            "certificateAuthorities": [
                "ca.org${ORG_NUM}.example.com"
            ]
        }
    },
    "peers": {
        "peer0.org${ORG_NUM}.example.com": {
            "url": "grpcs://localhost:${PEER_PORT}",
            "tlsCACerts": {
                "pem": "${PP}"
            },
            "grpcOptions": {
                "ssl-target-name-override": "peer0.org${ORG_NUM}.example.com",
                "hostnameOverride": "peer0.org${ORG_NUM}.example.com"
            }
        }
    },
    "certificateAuthorities": {
        "ca.org${ORG_NUM}.example.com": {
            "url": "https://localhost:${CA_PORT}",
            "caName": "ca-org${ORG_NUM}",
            "tlsCACerts": {
                "pem": "${CP}"
            },
            "httpOptions": {
                "verify": false
            }
        }
    }
}
EOF

  cat > ../organizations/peerOrganizations/org${ORG_NUM}.example.com/connection-org${ORG_NUM}.yaml <<EOF
---
name: test-network-org${ORG_NUM}
version: 1.0.0
client:
  organization: Org${ORG_NUM}
  connection:
    timeout:
      peer:
        endorser: '300'
organizations:
  Org${ORG_NUM}:
    mspid: Org${ORG_NUM}MSP
    peers:
    - peer0.org${ORG_NUM}.example.com
    certificateAuthorities:
    - ca.org${ORG_NUM}.example.com
peers:
  peer0.org${ORG_NUM}.example.com:
    url: grpcs://localhost:${PEER_PORT}
    tlsCACerts:
      path: organizations/peerOrganizations/org${ORG_NUM}.example.com/tlsca/tlsca.org${ORG_NUM}.example.com-cert.pem
    grpcOptions:
      ssl-target-name-override: peer0.org${ORG_NUM}.example.com
      hostnameOverride: peer0.org${ORG_NUM}.example.com
certificateAuthorities:
  ca.org${ORG_NUM}.example.com:
    url: https://localhost:${CA_PORT}
    caName: ca-org${ORG_NUM}
    tlsCACerts:
      path: organizations/peerOrganizations/org${ORG_NUM}.example.com/ca/ca.org${ORG_NUM}.example.com-cert.pem
    httpOptions:
      verify: false
EOF
}

# Create Organization crypto material
function generateOrg() {
  calculatePorts
  generateComposeFiles
  
  if [ "$CRYPTO" == "cryptogen" ]; then
    generateOrgCrypto
  fi

  if [ "$CRYPTO" == "Certificate Authorities" ]; then
    generateOrgCryptoCA
  fi

  generateCCP
}

function OrgUp () {
  calculatePorts
  generateComposeFiles
  
  if [ "$CONTAINER_CLI" == "podman" ]; then
    cp ../podman/core.yaml ../../organizations/peerOrganizations/org${ORG_NUM}.example.com/peers/peer0.org${ORG_NUM}.example.com/
  fi

  COMPOSE_FILES="-f compose/compose-org${ORG_NUM}.yaml -f compose/${CONTAINER_CLI}/docker-compose-org${ORG_NUM}.yaml"
  
  if [ "${DATABASE}" == "couchdb" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f compose/compose-couch-org${ORG_NUM}.yaml -f compose/${CONTAINER_CLI}/docker-compose-couch-org${ORG_NUM}.yaml"
  fi

  DOCKER_SOCK=${DOCKER_SOCK} ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} up -d 2>&1
  
  if [ $? -ne 0 ]; then
    fatalln "ERROR !!!! Unable to start Org${ORG_NUM} network"
  fi
}

# Update channel config to add new org
function updateChannelConfig() {
  export FABRIC_CFG_PATH=${PWD}/../../config
  
  infoln "Fetching channel config for ${CHANNEL_NAME}"
  
  # Set env for Org1
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID=Org1MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/../organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  export CORE_PEER_ADDRESS=localhost:7051
  export ORDERER_CA=${PWD}/../organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

  set -x
  peer channel fetch config ../channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c ${CHANNEL_NAME} --tls --cafile "$ORDERER_CA"
  { set +x; } 2>/dev/null

  infoln "Decoding config block to JSON"
  set -x
  configtxlator proto_decode --input ../channel-artifacts/config_block.pb --type common.Block --output ../channel-artifacts/config_block.json
  jq '.data.data[0].payload.data.config' ../channel-artifacts/config_block.json > ../channel-artifacts/config.json
  { set +x; } 2>/dev/null

  infoln "Adding Org${ORG_NUM} to config"
  set -x
  jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org'${ORG_NUM}'MSP":.[1]}}}}}' ../channel-artifacts/config.json ../organizations/peerOrganizations/org${ORG_NUM}.example.com/org${ORG_NUM}.json > ../channel-artifacts/modified_config.json
  { set +x; } 2>/dev/null

  infoln "Creating config update"
  set -x
  configtxlator proto_encode --input ../channel-artifacts/config.json --type common.Config --output ../channel-artifacts/original_config.pb
  configtxlator proto_encode --input ../channel-artifacts/modified_config.json --type common.Config --output ../channel-artifacts/modified_config.pb
  configtxlator compute_update --channel_id ${CHANNEL_NAME} --original ../channel-artifacts/original_config.pb --updated ../channel-artifacts/modified_config.pb --output ../channel-artifacts/config_update.pb
  configtxlator proto_decode --input ../channel-artifacts/config_update.pb --type common.ConfigUpdate --output ../channel-artifacts/config_update.json
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_NAME}'", "type":2}},"data":{"config_update":'$(cat ../channel-artifacts/config_update.json)'}}}' | jq . > ../channel-artifacts/config_update_in_envelope.json
  configtxlator proto_encode --input ../channel-artifacts/config_update_in_envelope.json --type common.Envelope --output ../channel-artifacts/org${ORG_NUM}_update_in_envelope.pb
  { set +x; } 2>/dev/null

  infoln "Signing config transaction as Org1"
  set -x
  peer channel signconfigtx -f ../channel-artifacts/org${ORG_NUM}_update_in_envelope.pb
  { set +x; } 2>/dev/null

  infoln "Submitting transaction from Org2"
  export CORE_PEER_LOCALMSPID=Org2MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/../organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
  export CORE_PEER_ADDRESS=localhost:9051

  set -x
  peer channel update -f ../channel-artifacts/org${ORG_NUM}_update_in_envelope.pb -c ${CHANNEL_NAME} -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA"
  { set +x; } 2>/dev/null

  successln "Config transaction to add Org${ORG_NUM} submitted"
}

# Join org peer to channel
function joinChannel() {
  export FABRIC_CFG_PATH=${PWD}/../../config
  
  # Set env for new org
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/tlsca/tlsca.org${ORG_NUM}.example.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/users/Admin@org${ORG_NUM}.example.com/msp
  export CORE_PEER_ADDRESS=localhost:${PEER_PORT}
  export ORDERER_CA=${PWD}/../organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

  BLOCKFILE="../channel-artifacts/${CHANNEL_NAME}.block"

  infoln "Fetching channel block from orderer..."
  set -x
  peer channel fetch 0 $BLOCKFILE -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME --tls --cafile "$ORDERER_CA"
  { set +x; } 2>/dev/null

  infoln "Joining Org${ORG_NUM} peer to the channel..."
  local rc=1
  local COUNTER=1
  while [ $rc -ne 0 -a $COUNTER -lt 5 ] ; do
    sleep 3
    set -x
    peer channel join -b $BLOCKFILE
    rc=$?
    { set +x; } 2>/dev/null
    COUNTER=$(expr $COUNTER + 1)
  done

  if [ $rc -ne 0 ]; then
    fatalln "After 5 attempts, peer0.org${ORG_NUM} has failed to join channel '$CHANNEL_NAME'"
  fi

  successln "Org${ORG_NUM} peer joined channel '${CHANNEL_NAME}'"
}

# Set anchor peer
function setAnchorPeer() {
  export FABRIC_CFG_PATH=${PWD}/../../config
  
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID=Org${ORG_NUM}MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/tlsca/tlsca.org${ORG_NUM}.example.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/../organizations/peerOrganizations/org${ORG_NUM}.example.com/users/Admin@org${ORG_NUM}.example.com/msp
  export CORE_PEER_ADDRESS=localhost:${PEER_PORT}
  export ORDERER_CA=${PWD}/../organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem

  infoln "Fetching channel config for anchor peer update"
  set -x
  peer channel fetch config ../channel-artifacts/config_block.pb -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c ${CHANNEL_NAME} --tls --cafile "$ORDERER_CA"
  { set +x; } 2>/dev/null

  set -x
  configtxlator proto_decode --input ../channel-artifacts/config_block.pb --type common.Block | jq '.data.data[0].payload.data.config' > ../channel-artifacts/Org${ORG_NUM}MSPconfig.json
  { set +x; } 2>/dev/null

  infoln "Generating anchor peer update transaction for Org${ORG_NUM}"
  HOST="peer0.org${ORG_NUM}.example.com"
  
  set -x
  jq '.channel_group.groups.Application.groups.Org'${ORG_NUM}'MSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'$HOST'","port": '$PEER_PORT'}]},"version": "0"}}' ../channel-artifacts/Org${ORG_NUM}MSPconfig.json > ../channel-artifacts/Org${ORG_NUM}MSPmodified_config.json
  { set +x; } 2>/dev/null

  set -x
  configtxlator proto_encode --input ../channel-artifacts/Org${ORG_NUM}MSPconfig.json --type common.Config --output ../channel-artifacts/original_config.pb
  configtxlator proto_encode --input ../channel-artifacts/Org${ORG_NUM}MSPmodified_config.json --type common.Config --output ../channel-artifacts/modified_config.pb
  configtxlator compute_update --channel_id ${CHANNEL_NAME} --original ../channel-artifacts/original_config.pb --updated ../channel-artifacts/modified_config.pb --output ../channel-artifacts/config_update.pb
  configtxlator proto_decode --input ../channel-artifacts/config_update.pb --type common.ConfigUpdate --output ../channel-artifacts/config_update.json
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_NAME}'", "type":2}},"data":{"config_update":'$(cat ../channel-artifacts/config_update.json)'}}}' | jq . > ../channel-artifacts/config_update_in_envelope.json
  configtxlator proto_encode --input ../channel-artifacts/config_update_in_envelope.json --type common.Envelope --output ../channel-artifacts/Org${ORG_NUM}MSPanchors.tx
  { set +x; } 2>/dev/null

  set -x
  peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c ${CHANNEL_NAME} -f ../channel-artifacts/Org${ORG_NUM}MSPanchors.tx --tls --cafile "$ORDERER_CA"
  { set +x; } 2>/dev/null

  successln "Anchor peer set for Org${ORG_NUM}MSP on channel '${CHANNEL_NAME}'"
}

# Add organization to network
function addOrg () {
  if [ ! -d ../organizations/ordererOrganizations ]; then
    fatalln "ERROR: Please, run ./network.sh up createChannel first."
  fi

  calculatePorts

  if [ ! -d "../organizations/peerOrganizations/org${ORG_NUM}.example.com" ]; then
    generateOrg
    generateOrgDefinition
  fi

  infoln "Bringing up Org${ORG_NUM} peer"
  OrgUp

  infoln "Generating and submitting config tx to add Org${ORG_NUM}"
  updateChannelConfig
  
  if [ $? -ne 0 ]; then
    fatalln "ERROR !!!! Unable to create config tx"
  fi

  infoln "Joining Org${ORG_NUM} peers to network"
  joinChannel
  
  if [ $? -ne 0 ]; then
    fatalln "ERROR !!!! Unable to join Org${ORG_NUM} peers to network"
  fi

  infoln "Setting anchor peer for Org${ORG_NUM}"
  setAnchorPeer

  successln "Org${ORG_NUM} successfully added to network on channel '${CHANNEL_NAME}'"
}

# Tear down running network
function networkDown () {
    cd ..
    ./network.sh down
}

# Default values
CRYPTO="cryptogen"
CLI_TIMEOUT=10
CLI_DELAY=3
CHANNEL_NAME="mychannel"
DATABASE="leveldb"
ORG_NUM=""

# Get docker sock path from environment variable
SOCK="${DOCKER_HOST:-/var/run/docker.sock}"
DOCKER_SOCK="${SOCK##unix://}"

# Parse commandline args
if [[ $# -lt 1 ]] ; then
  printHelp
  exit 0
else
  MODE=$1
  shift
fi

# parse flags
while [[ $# -ge 1 ]] ; do
  key="$1"
  case $key in
  -h )
    printHelp
    exit 0
    ;;
  -org )
    ORG_NUM="$2"
    shift
    ;;
  -c )
    CHANNEL_NAME="$2"
    shift
    ;;
  -ca )
    CRYPTO="Certificate Authorities"
    ;;
  -t )
    CLI_TIMEOUT="$2"
    shift
    ;;
  -d )
    CLI_DELAY="$2"
    shift
    ;;
  -s )
    DATABASE="$2"
    shift
    ;;
  -verbose )
    VERBOSE=true
    ;;
  * )
    errorln "Unknown flag: $key"
    printHelp
    exit 1
    ;;
  esac
  shift
done

# Validate org number is provided
if [ "$MODE" != "down" ] && [ -z "$ORG_NUM" ]; then
  fatalln "Organization number is required. Use -org <number>"
fi

# Validate org number is numeric
if [ -n "$ORG_NUM" ] && ! [[ "$ORG_NUM" =~ ^[0-9]+$ ]]; then
  fatalln "Organization number must be a positive integer"
fi

# Determine mode
if [ "$MODE" == "up" ]; then
  infoln "Adding Org${ORG_NUM} to channel '${CHANNEL_NAME}' with '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds and using database '${DATABASE}'"
  echo
elif [ "$MODE" == "down" ]; then
  EXPMODE="Stopping network"
elif [ "$MODE" == "generate" ]; then
  EXPMODE="Generating certs and organization definition for Org${ORG_NUM}"
else
  printHelp
  exit 1
fi

# Execute based on mode
if [ "${MODE}" == "up" ]; then
  addOrg
elif [ "${MODE}" == "down" ]; then
  networkDown
elif [ "${MODE}" == "generate" ]; then
  calculatePorts
  generateComposeFiles
  generateOrg
  generateOrgDefinition
else
  printHelp
  exit 1
fi
