# BitCoil — BTC Leverage Looping Vault

**Automated leverage looping for BTC on Starknet.**

Deposit wrapped BTC. Get leveraged BTC exposure. One transaction.

Built for the [Starknet Re{define} Hackathon](https://dorahacks.io/hackathon/redefine) — Bitcoin Track.

---

## The Problem

BTC holders who want leveraged exposure today must manually:
1. Deposit BTC as collateral
2. Borrow stablecoins
3. Swap stablecoins back to BTC
4. Re-deposit and repeat

This is tedious, error-prone, and gas-expensive. Each step is a separate transaction with slippage and timing risk.

## The Solution

BitCoil automates the entire leverage loop in a **single transaction**. Deposit WBTC, choose your leverage (1.5x-3x), and the vault handles the rest.

```
User deposits 1 WBTC
  -> Vault deposits to Vesu V2 as collateral
  -> Vault borrows USDC (65% LTV)
  -> Vault swaps USDC -> WBTC via Ekubo
  -> Vault re-deposits new WBTC
  -> Repeats N times
  -> Result: ~2-2.5x leveraged BTC exposure
```

### Why Starknet?

- **Native multicall** -- all accounts are smart contracts; multi-step loops execute atomically
- **BTCFi Season** -- 100M STRK incentives subsidize BTC borrowing (0-1% effective APR)
- **Sub-cent gas** -- each loop iteration costs fractions of a cent
- **Rich BTC ecosystem** -- WBTC, LBTC, tBTC, SolvBTC with $130M+ TVL

---

## How It Works

### Leverage Table

Starting with 1 WBTC ($100K) at 65% LTV per loop:

| Loops | Effective Leverage | Health Factor | Price Drop to Liquidation |
|-------|-------------------|---------------|---------------------------|
| 1 | 1.65x | 1.90 | -47% |
| 2 | 2.07x | 1.45 | -31% |
| 3 | 2.35x | 1.31 | -24% |
| 4 | 2.53x | 1.24 | -19% |

**Default: 2-3 loops (~2x leverage)** for a safe balance of returns vs risk.

### Unwinding

To exit, the vault reverses the process: withdraw collateral -> swap BTC to USDC -> repay debt -> withdraw more -> repeat until fully unwound.

---

## Architecture

```
                    +------------------+
                    |      User        |
                    |  (Xverse/Argent/ |
                    |   Braavos)       |
                    +--------+---------+
                             | deposit_and_loop(amount, loops)
                             v
                    +------------------+
                    |  BitCoil    |
                    |                  |
                    |  Orchestrates    |
                    |  the leverage    |
                    |  loop + tracks   |
                    |  positions       |
                    +--+----------+----+
                       |          |
            +----------+          +----------+
            v                                v
   +-----------------+           +------------------+
   |    Vesu V2       |           |   Ekubo DEX      |
   |                  |           |                  |
   |  deposit WBTC    |           |  swap USDC->WBTC |
   |  borrow USDC     |           |  deepest BTC     |
   |  flash loans     |           |  liquidity       |
   |  (zero fee!)     |           |                  |
   +-----------------+           +------------------+
            |
            v
   +-----------------+
   |  Pyth Oracle   |
   |                  |
   |  BTC/USD price   |
   |  Health factor   |
   +-----------------+
```

---

## Tech Stack

| Component | Tool |
|-----------|------|
| Smart Contracts | Cairo 2.15+ |
| Build | Scarb |
| Testing | Starknet Foundry (snforge) |
| Deployment | sncast / Starkli |
| Lending | Vesu V2 |
| Swaps | Ekubo Router V3 |
| Oracle | Pyth Network (BTC/USD) |
| BTC Asset | WBTC (8 decimals) |
| Stablecoin | USDC |
| Frontend | Next.js + starknet-react |
| BTC Wallet | Xverse (Sats Connect) |

---

## Quick Start

### Prerequisites

```bash
# Install Scarb (Cairo package manager)
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh

# Install Starknet Foundry
curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh
snfoundryup

# Install Starkli (optional, for manual deployment)
curl https://get.starkli.sh | sh && starkliup
```

### Build

```bash
scarb build
```

### Test

```bash
snforge test        # Run all 44 tests
snforge test vault  # Run vault integration tests only
snforge test math   # Run leverage math tests only
snforge test security  # Run security tests only
```

**44 tests** covering:
- Deposit, loop, unwind, full unwind flows
- Leverage calculation accuracy (1-4 loops)
- Health factor monitoring
- Access control (owner-only admin functions)
- Pause/unpause emergency controls
- Slippage protection
- Edge cases (zero amounts, double deposits, insufficient balance/allowance)

### Deploy (Sepolia Testnet)

```bash
# Create and fund account
sncast account create --name deployer --network sepolia
# Fund via https://starknet-faucet.vercel.app/
sncast account deploy --name deployer --network sepolia

# Declare contract class
sncast --account deployer declare --contract-name BitCoil --network sepolia

# Deploy instance
sncast --account deployer deploy \
  --class-hash <CLASS_HASH> \
  --constructor-calldata <VESU_ADDR> <EKUBO_ADDR> <PYTH_ADDR> <WBTC_ADDR> <USDC_ADDR> <POOL_ID> \
  --network sepolia
```

---

## Contract Addresses

### Sepolia Testnet

| Contract | Address |
|----------|---------|
| BitCoil | TBD |

### Mainnet

| Contract | Address |
|----------|---------|
| BitCoil | TBD |

### External Contracts (Mainnet)

| Contract | Address |
|----------|---------|
| WBTC | `0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac` |
| USDC | `0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8` |
| Vesu Re7 xBTC Pool | `0x3a8416bf20d036df5b1cf3447630a2e1cb04685f6b0c3a70ed7fb1473548ecf` |
| Ekubo Router V3 | `0x0199741822c2dc722f6f605204f35e56dbc23bceed54818168c4c49e4fb8737e` |
| Pyth Oracle | `0x062ab68d8e23a7aa0d5bf4d25380c2d54f2dd8f83012e047851c3706b53d64d1` |

---

## Project Structure

```
src/
  lib.cairo              # Module declarations
  vault.cairo            # BitCoil contract (core logic)
  types.cairo            # Position struct, events, errors
  utils.cairo            # Leverage math helpers
  interfaces/
    i_vault.cairo        # IBitCoil trait
    i_vesu.cairo         # IVesuSingleton trait
    i_ekubo.cairo        # IEkuboRouter trait
    i_pyth.cairo         # IPyth trait
    i_erc20.cairo        # IERC20 trait
  mock_erc20.cairo       # Mock ERC20 for testing
  mock_lending.cairo     # Mock Vesu for testing
  mock_dex.cairo         # Mock Ekubo for testing
tests/
  test_vault.cairo       # Integration tests (22 tests)
  test_leverage_math.cairo  # Math unit tests (12 tests)
  test_security.cairo    # Security & access control (10 tests)
scripts/
  deploy_sepolia.sh      # Testnet deployment script
```

---

## Key Risks

- **Liquidation**: If BTC price drops, leveraged positions face amplified losses. The vault enforces a minimum health factor and supports emergency unwind.
- **Slippage**: Each loop iteration involves a swap. Configurable slippage tolerance protects users.
- **Smart contract risk**: New Cairo code, unaudited. Use at own risk.
- **Oracle risk**: Health factor depends on Pyth price feeds. Staleness checks mitigate delayed data.

---

## DeFi Integrations

| Protocol | Role | Why |
|----------|------|-----|
| [Vesu V2](https://vesu.xyz) | Lending/borrowing | Free flash loans, BTCFi pools, $160M+ TVL, open-source |
| [Ekubo](https://ekubo.org) | DEX swaps | 60% of Starknet AMM TVL, deepest WBTC/USDC liquidity |
| [Pyth Network](https://pyth.network) | Price oracle | Pull oracle on Starknet, BTC/USD feed |
| [Xverse](https://xverse.app) | BTC wallet | Native Bitcoin wallet with Starknet support |

---

## Hackathon

- **Event**: [Starknet Re{define} Hackathon](https://dorahacks.io/hackathon/redefine)
- **Track**: Bitcoin ($9,675 STRK + $5,500 Xverse in-kind)
- **Deadline**: February 28, 2026
- **Submission**: DoraHacks BUIDL

---

## License

MIT
