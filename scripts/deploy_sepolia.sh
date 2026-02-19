#!/bin/bash
# BitCoil Sepolia Deployment Script
# Prerequisites:
#   1. Create account: sncast --profile sepolia account create --name deployer
#   2. Fund with Sepolia STRK (faucet: https://starknet-faucet.vercel.app/)
#   3. Deploy account: sncast --profile sepolia account deploy --name deployer
#
# Usage: ./scripts/deploy_sepolia.sh

set -euo pipefail

PROFILE="sepolia"

# Sepolia addresses
OWNER=""  # Set to your deployer account address
PYTH="0x07f2b07b6b5365e7ee055bda4c0ecabd867e6d3ee298d73aea32b027667186d6"
WBTC="0x00452bd5c0512a61df7c7be8cfea5e4f893cb40e126bdc40aee6054db955129e"
BTC_USD_FEED="0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43"

# Placeholder addresses — replace with real Sepolia Vesu/Ekubo when available
VESU_SINGLETON="0x0"  # TODO: Vesu Sepolia singleton
POOL_ID="0x0"         # TODO: Vesu pool ID
EKUBO_ROUTER="0x0"    # TODO: Ekubo Sepolia router
USDC="0x0"            # TODO: Sepolia USDC

# Initial BTC price: $100,000 in USDC (6 decimals) = 100_000_000_000
BTC_PRICE="100000000000"

echo "=== BitCoil Sepolia Deployment ==="

# Step 1: Declare
echo "[1/2] Declaring BitCoil contract..."
DECLARE_OUTPUT=$(sncast --profile $PROFILE declare --contract-name BitCoil 2>&1)
echo "$DECLARE_OUTPUT"
CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep "class_hash:" | awk '{print $2}')
echo "Class hash: $CLASS_HASH"

# Step 2: Deploy
echo "[2/2] Deploying BitCoil contract..."
sncast --profile $PROFILE deploy \
    --class-hash "$CLASS_HASH" \
    --constructor-calldata \
        "$OWNER" \
        "$VESU_SINGLETON" \
        "$POOL_ID" \
        "$EKUBO_ROUTER" \
        "$PYTH" \
        "$WBTC" \
        "$USDC" \
        "$BTC_USD_FEED" 0 \
        "$BTC_PRICE" 0

echo "=== Deployment Complete ==="
