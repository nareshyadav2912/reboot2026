#!/bin/bash
#
# Script to set environment variables for Hyperledger Fabric organizations
# Usage: source ./setOrg.sh
#

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set common variables
export PATH="${SCRIPT_DIR}/../bin:$PATH"
export FABRIC_CFG_PATH="${SCRIPT_DIR}/../config"
export CORE_PEER_TLS_ENABLED=true

# Orderer CA (common for all orgs)
export ORDERER_CA="${SCRIPT_DIR}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem"

# TLS certificates for all orgs
export PEER0_ORG1_CA="${SCRIPT_DIR}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem"
export PEER0_ORG2_CA="${SCRIPT_DIR}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem"
export PEER0_ORG3_CA="${SCRIPT_DIR}/organizations/peerOrganizations/org3.example.com/tlsca/tlsca.org3.example.com-cert.pem"
export PEER0_ORG4_CA="${SCRIPT_DIR}/organizations/peerOrganizations/org4.example.com/tlsca/tlsca.org4.example.com-cert.pem"

echo ""
echo "========================================"
echo "  Hyperledger Fabric - Set Organization"
echo "========================================"
echo ""
echo "Select organization:"
echo "  1) Broker        (localhost:7051)"
echo "  2) Lender        (localhost:9051)"
echo "  3) Conveyancer   (localhost:11051)"
echo "  4) Estate Agent  (localhost:11061)"
echo ""
printf "Enter org number [1-4]: "
read ORG_NUM </dev/tty

case $ORG_NUM in
    1)
        export CORE_PEER_LOCALMSPID="Org1MSP"
        export CORE_PEER_TLS_ROOTCERT_FILE="${SCRIPT_DIR}/organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem"
        export CORE_PEER_MSPCONFIGPATH="${SCRIPT_DIR}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
        export CORE_PEER_ADDRESS=localhost:7051
        ORG_NAME="Broker"
        ;;
    2)
        export CORE_PEER_LOCALMSPID="Org2MSP"
        export CORE_PEER_TLS_ROOTCERT_FILE="${SCRIPT_DIR}/organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem"
        export CORE_PEER_MSPCONFIGPATH="${SCRIPT_DIR}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"
        export CORE_PEER_ADDRESS=localhost:9051
        ORG_NAME="Lender"
        ;;
    3)
        export CORE_PEER_LOCALMSPID="Org3MSP"
        export CORE_PEER_TLS_ROOTCERT_FILE="${SCRIPT_DIR}/organizations/peerOrganizations/org3.example.com/tlsca/tlsca.org3.example.com-cert.pem"
        export CORE_PEER_MSPCONFIGPATH="${SCRIPT_DIR}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp"
        export CORE_PEER_ADDRESS=localhost:11051
        ORG_NAME="Conveyancer"
        ;;
    4)
        export CORE_PEER_LOCALMSPID="Org4MSP"
        export CORE_PEER_TLS_ROOTCERT_FILE="${SCRIPT_DIR}/organizations/peerOrganizations/org4.example.com/tlsca/tlsca.org4.example.com-cert.pem"
        export CORE_PEER_MSPCONFIGPATH="${SCRIPT_DIR}/organizations/peerOrganizations/org4.example.com/users/Admin@org4.example.com/msp"
        export CORE_PEER_ADDRESS=localhost:11061
        ORG_NAME="Estate Agent"
        ;;
    *)
        echo "Invalid selection. Please enter 1, 2, 3, or 4."
        return 1 2>/dev/null || exit 1
        ;;
esac

echo ""
echo "✓ Environment set for: $ORG_NAME"
echo ""
echo "Current settings:"
echo "  CORE_PEER_LOCALMSPID:    $CORE_PEER_LOCALMSPID"
echo "  CORE_PEER_ADDRESS:       $CORE_PEER_ADDRESS"
echo ""
echo "Ready to run peer commands!"
echo ""
