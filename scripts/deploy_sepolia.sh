#!/bin/bash
# BitCoil — Full Sepolia Deployment Script
# Deploys MockERC20 (WBTC, USDC), MockLending, MockDEX, and BitCoil
#
# Prerequisites:
#   1. Fund the account with Sepolia STRK: https://starknet-faucet.vercel.app/
#   2. Deploy the account: sncast account deploy --network sepolia --name bitcoil
#
# Usage: ./scripts/deploy_sepolia.sh
#
# The script uses --network sepolia (built-in public RPC) for compatibility.

set -euo pipefail

ACCOUNT="bitcoil"
NETWORK_FLAG="--network sepolia"

# Sepolia addresses (real contracts)
PYTH="0x07f2b07b6b5365e7ee055bda4c0ecabd867e6d3ee298d73aea32b027667186d6"
BTC_USD_FEED="0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43"

# BTC price: $100,000 in USDC (6 decimals) = 100_000_000_000
BTC_PRICE="100000000000"

echo "=== BitCoil Sepolia Deployment ==="
echo ""

# Check account balance
echo "[0/7] Checking account balance..."
sncast --account $ACCOUNT balance $NETWORK_FLAG || {
    echo "ERROR: Cannot check balance. Is the account funded and deployed?"
    echo "1. Fund at: https://starknet-faucet.vercel.app/"
    echo "2. Deploy: sncast account deploy $NETWORK_FLAG --name $ACCOUNT"
    exit 1
}
echo ""

# Build
echo "[1/7] Building contracts..."
scarb build
echo ""

# Declare all contracts
echo "[2/7] Declaring MockERC20..."
MOCK_ERC20_OUT=$(sncast --account $ACCOUNT $NETWORK_FLAG declare --contract-name MockERC20 2>&1) || {
    # Check if already declared
    if echo "$MOCK_ERC20_OUT" | grep -q "already declared"; then
        MOCK_ERC20_HASH=$(echo "$MOCK_ERC20_OUT" | grep -oP '0x[0-9a-fA-F]+' | head -1)
        echo "Already declared: $MOCK_ERC20_HASH"
    else
        echo "$MOCK_ERC20_OUT"
        exit 1
    fi
}
MOCK_ERC20_HASH=$(echo "$MOCK_ERC20_OUT" | grep "Class Hash:" | awk '{print $3}')
echo "MockERC20 class hash: $MOCK_ERC20_HASH"

echo "[3/7] Declaring MockLending..."
MOCK_LENDING_OUT=$(sncast --account $ACCOUNT $NETWORK_FLAG declare --contract-name MockLending 2>&1) || true
MOCK_LENDING_HASH=$(echo "$MOCK_LENDING_OUT" | grep "Class Hash:" | awk '{print $3}')
echo "MockLending class hash: $MOCK_LENDING_HASH"

echo "[4/7] Declaring MockDEX..."
MOCK_DEX_OUT=$(sncast --account $ACCOUNT $NETWORK_FLAG declare --contract-name MockDEX 2>&1) || true
MOCK_DEX_HASH=$(echo "$MOCK_DEX_OUT" | grep "Class Hash:" | awk '{print $3}')
echo "MockDEX class hash: $MOCK_DEX_HASH"

echo "[5/7] Declaring BitCoil..."
BITCOIL_OUT=$(sncast --account $ACCOUNT $NETWORK_FLAG declare --contract-name BitCoil 2>&1) || true
BITCOIL_HASH=$(echo "$BITCOIL_OUT" | grep "Class Hash:" | awk '{print $3}')
echo "BitCoil class hash: $BITCOIL_HASH"
echo ""

# Deploy mock tokens
# felt252 for 'WBTC' = 0x57425443, decimals = 8
# felt252 for 'USDC' = 0x55534443, decimals = 6
echo "[6/7] Deploying mock contracts..."

echo "  Deploying MockERC20 (WBTC)..."
WBTC_OUT=$(sncast --account $ACCOUNT $NETWORK_FLAG deploy --class-hash "$MOCK_ERC20_HASH" --arguments "0x57425443, 0x57425443, 8" 2>&1)
WBTC=$(echo "$WBTC_OUT" | grep "Contract Address:" | awk '{print $3}')
echo "  WBTC: $WBTC"

echo "  Deploying MockERC20 (USDC)..."
USDC_OUT=$(sncast --account $ACCOUNT $NETWORK_FLAG deploy --class-hash "$MOCK_ERC20_HASH" --arguments "0x55534443, 0x55534443, 6" --salt 0x1 2>&1)
USDC=$(echo "$USDC_OUT" | grep "Contract Address:" | awk '{print $3}')
echo "  USDC: $USDC"

echo "  Deploying MockLending..."
LENDING_OUT=$(sncast --account $ACCOUNT $NETWORK_FLAG deploy --class-hash "$MOCK_LENDING_HASH" 2>&1)
VESU=$(echo "$LENDING_OUT" | grep "Contract Address:" | awk '{print $3}')
echo "  MockLending (Vesu): $VESU"

echo "  Deploying MockDEX..."
DEX_OUT=$(sncast --account $ACCOUNT $NETWORK_FLAG deploy --class-hash "$MOCK_DEX_HASH" --arguments "$WBTC, $USDC, $BTC_PRICE" 2>&1)
EKUBO=$(echo "$DEX_OUT" | grep "Contract Address:" | awk '{print $3}')
echo "  MockDEX (Ekubo): $EKUBO"
echo ""

# Get owner address from accounts file
OWNER=$(python3 -c "
import json
with open('$HOME/.starknet_accounts/starknet_open_zeppelin_accounts.json') as f:
    data = json.load(f)
print(data['alpha-sepolia']['$ACCOUNT']['address'])
")

# Deploy BitCoil
echo "[7/7] Deploying BitCoil..."
BITCOIL_DEPLOY_OUT=$(sncast --account $ACCOUNT $NETWORK_FLAG deploy \
    --class-hash "$BITCOIL_HASH" \
    --arguments "$OWNER, $VESU, 0x1, $EKUBO, $PYTH, $WBTC, $USDC, $BTC_USD_FEED, $BTC_PRICE" 2>&1)
BITCOIL_ADDR=$(echo "$BITCOIL_DEPLOY_OUT" | grep "Contract Address:" | awk '{print $3}')
echo "BitCoil: $BITCOIL_ADDR"
echo ""

# Verify
echo "=== Verifying deployment ==="
echo "Calling get_position..."
sncast --account $ACCOUNT $NETWORK_FLAG call \
    --contract-address "$BITCOIL_ADDR" \
    --function get_position \
    --arguments "$OWNER"

echo ""
echo "Calling owner..."
sncast --account $ACCOUNT $NETWORK_FLAG call \
    --contract-address "$BITCOIL_ADDR" \
    --function owner

echo ""
echo "=== Deployment Summary ==="
echo "WBTC (Mock):        $WBTC"
echo "USDC (Mock):        $USDC"
echo "MockLending (Vesu): $VESU"
echo "MockDEX (Ekubo):    $EKUBO"
echo "BitCoil Vault:      $BITCOIL_ADDR"
echo ""
echo "Explorer: https://sepolia.starkscan.co/contract/$BITCOIL_ADDR"
echo "=== Done ==="
