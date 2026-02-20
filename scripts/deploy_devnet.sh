#!/bin/bash
# BitCoil — Local Devnet Deployment Script
# Deploys all contracts to starknet-devnet for local testing
#
# Prerequisites:
#   1. Install starknet-devnet: https://github.com/0xSpaceShard/starknet-devnet
#   2. Start devnet: starknet-devnet --port 5050 --seed 42
#   3. Import account: sncast account import --name devnet-deployer \
#        --address 0x034ba56f92265f0868c57d3fe72ecab144fc96f97954bbbc4252cef8e8a979ba \
#        --private-key 0x00000000000000000000000000000000b137668388dbe9acdfa3bc734cc2c469 \
#        --type open-zeppelin --network devnet --add-profile devnet --silent
#
# Usage: ./scripts/deploy_devnet.sh

set -euo pipefail

PROFILE="devnet"
DEPLOYER="0x034ba56f92265f0868c57d3fe72ecab144fc96f97954bbbc4252cef8e8a979ba"
PYTH_DUMMY="0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
BTC_USD_FEED="0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43"
BTC_PRICE="100000000000"  # $100k in USDC 6-decimal

echo "=== BitCoil Devnet Deployment ==="

# Check devnet is running
curl -s http://localhost:5050/is_alive > /dev/null 2>&1 || {
    echo "ERROR: starknet-devnet not running. Start it with:"
    echo "  starknet-devnet --port 5050 --seed 42"
    exit 1
}
echo "Devnet is alive."

# Build
echo "[1/7] Building..."
scarb build

# Declare all contracts
echo "[2/7] Declaring contracts..."
MOCK_ERC20_HASH=$(sncast -p $PROFILE declare --contract-name MockERC20 2>&1 | grep "Class Hash:" | awk '{print $3}')
echo "  MockERC20: $MOCK_ERC20_HASH"

MOCK_LENDING_HASH=$(sncast -p $PROFILE declare --contract-name MockLending 2>&1 | grep "Class Hash:" | awk '{print $3}')
echo "  MockLending: $MOCK_LENDING_HASH"

MOCK_DEX_HASH=$(sncast -p $PROFILE declare --contract-name MockDEX 2>&1 | grep "Class Hash:" | awk '{print $3}')
echo "  MockDEX: $MOCK_DEX_HASH"

BITCOIL_HASH=$(sncast -p $PROFILE declare --contract-name BitCoil 2>&1 | grep "Class Hash:" | awk '{print $3}')
echo "  BitCoil: $BITCOIL_HASH"

# Deploy mocks
echo "[3/7] Deploying MockERC20 (WBTC)..."
WBTC=$(sncast -p $PROFILE deploy --class-hash "$MOCK_ERC20_HASH" --arguments "0x57425443, 0x57425443, 8" 2>&1 | grep "Contract Address:" | awk '{print $3}')
echo "  WBTC: $WBTC"

echo "[4/7] Deploying MockERC20 (USDC)..."
USDC=$(sncast -p $PROFILE deploy --class-hash "$MOCK_ERC20_HASH" --arguments "0x55534443, 0x55534443, 6" --salt 0x1 2>&1 | grep "Contract Address:" | awk '{print $3}')
echo "  USDC: $USDC"

echo "[5/7] Deploying MockLending..."
VESU=$(sncast -p $PROFILE deploy --class-hash "$MOCK_LENDING_HASH" 2>&1 | grep "Contract Address:" | awk '{print $3}')
echo "  MockLending: $VESU"

echo "[6/7] Deploying MockDEX..."
EKUBO=$(sncast -p $PROFILE deploy --class-hash "$MOCK_DEX_HASH" --arguments "$WBTC, $USDC, $BTC_PRICE" 2>&1 | grep "Contract Address:" | awk '{print $3}')
echo "  MockDEX: $EKUBO"

# Deploy BitCoil
echo "[7/7] Deploying BitCoil..."
BITCOIL=$(sncast -p $PROFILE deploy \
    --class-hash "$BITCOIL_HASH" \
    --arguments "$DEPLOYER, $VESU, 0x1, $EKUBO, $PYTH_DUMMY, $WBTC, $USDC, $BTC_USD_FEED, $BTC_PRICE" 2>&1 | grep "Contract Address:" | awk '{print $3}')
echo "  BitCoil: $BITCOIL"

# Verify
echo ""
echo "=== Verifying ==="
sncast -p $PROFILE call --contract-address "$BITCOIL" --function owner
sncast -p $PROFILE call --contract-address "$BITCOIL" --function get_position --arguments "$DEPLOYER"

echo ""
echo "=== Deployment Summary ==="
echo "WBTC (Mock):        $WBTC"
echo "USDC (Mock):        $USDC"
echo "MockLending (Vesu): $VESU"
echo "MockDEX (Ekubo):    $EKUBO"
echo "BitCoil Vault:      $BITCOIL"
echo "=== Done ==="
