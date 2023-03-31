#!/usr/bin/env bash

set -euo pipefail

function usage() {
cat <<EOF >&2
Usage:
  $(basename "$0") <devnet|testnet|mainnet> -- Deploy the contracts
EOF
exit 1
}

NETWORK=$1 || usage

if [ "$NETWORK" = mainnet ]; then
  echo "Mainnet not supported yet"
  exit 1
elif [ "$NETWORK" = testnet ]; then
  echo "Testnet not supported yet"
  exit 1
elif [ "$NETWORK" = devnet ]; then
  GUARDIAN_ADDR=befa429d57cd18b7f8a4d91a2da9ab4af05d0fbe
else
  usage
fi

echo -e "[1/4] Publishing core bridge contracts..."
WORMHOLE_PUBLISH_OUTPUT=$(worm sui deploy wormhole -n "$NETWORK")
WORMHOLE_PACKAGE_ID=$(echo "$WORMHOLE_PUBLISH_OUTPUT" | grep -oP 'Deployed to: +\K.*')
echo "$WORMHOLE_PUBLISH_OUTPUT"

echo -e "\n[2/4] Publishing token bridge contracts..."
TOKEN_BRIDGE_PUBLISH_OUTPUT=$(worm sui deploy token_bridge -n "$NETWORK" --named-addresses "wormhole=$WORMHOLE_PACKAGE_ID")
echo "$TOKEN_BRIDGE_PUBLISH_OUTPUT"

echo -e "\n[3/4] Initializing core bridge..."
WORMHOLE_INIT_OUTPUT=$(worm sui init-wormhole -n "$NETWORK" --initial-guardian "$GUARDIAN_ADDR" -p "$WORMHOLE_PACKAGE_ID")
WORMHOLE_STATE_OBJECT_ID=$(echo "$WORMHOLE_INIT_OUTPUT" | grep -oP 'Wormhole state object ID: +\K.*')
echo "$WORMHOLE_INIT_OUTPUT"

echo -e "\n[4/4] Initializing token bridge..."
TOKEN_BRIDGE_PACKAGE_ID=$(echo "$TOKEN_BRIDGE_PUBLISH_OUTPUT" | grep -oP 'Deployed to: +\K.*')
worm sui init-token-bridge -n "$NETWORK" -p "$TOKEN_BRIDGE_PACKAGE_ID" --wormhole-state "$WORMHOLE_STATE_OBJECT_ID"

if [ "$NETWORK" = devnet ]; then
  echo -e "\n[+1] Deploying and initializing example contract..."
  EXAMPLE_PUBLISH_OUTPUT=$(worm sui deploy examples/core_messages -n "$NETWORK" --named-addresses "wormhole=$WORMHOLE_PACKAGE_ID")
  EXAMPLE_PACKAGE_ID=$(echo "$EXAMPLE_PUBLISH_OUTPUT" | grep -oP 'Deployed to: +\K.*')
  echo "$EXAMPLE_PUBLISH_OUTPUT"
  EXAMPLE_INIT_OUTPUT=$(sui client call --function init_with_params --module sender --package "$EXAMPLE_PACKAGE_ID" --gas-budget 20000 --args "$WORMHOLE_STATE_OBJECT_ID")
  EXAMPLE_INIT_CREATED_OBJECTS=$(echo "$EXAMPLE_INIT_OUTPUT" | grep -oPm1 ' +- ID: \K([a-z0-9]*) (?=.*)')
  echo "Example app state object ID: $EXAMPLE_INIT_CREATED_OBJECTS"
fi

echo -e "\nDeployments successful!"