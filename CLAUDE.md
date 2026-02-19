# CLAUDE.md — BitCoil Development Guide

## Project
**BitCoil** — Automated BTC Leverage Looping Vault on Starknet
Hackathon: Starknet Re{define} (Bitcoin Track) | Deadline: Feb 28, 2026

## What It Does
Users deposit wrapped BTC → vault loops through Vesu (lend/borrow) + Ekubo (swap) to create leveraged long BTC exposure. Single transaction, configurable leverage.

## Tech Stack
- **Language:** Cairo 2.16+
- **Build:** Scarb 2.16+
- **Testing:** Starknet Foundry (snforge 0.56+)
- **Deploy:** sncast
- **Oracle:** Pyth Network (pull oracle)
- **Lending:** Vesu V2
- **DEX:** Ekubo Router V3
- **Frontend:** Next.js + starknet-react (stretch goal)

## Key Addresses (Sepolia)
- Pyth: `0x07f2b07b6b5365e7ee055bda4c0ecabd867e6d3ee298d73aea32b027667186d6`
- BTC/USD Feed: `0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43`
- WBTC: `0x00452bd5c0512a61df7c7be8cfea5e4f893cb40e126bdc40aee6054db955129e`

## Key Addresses (Mainnet)
- Pyth: `0x062ab68d8e23a7aa0d5bf4d25380c2d54f2dd8f83012e047851c3706b53d64d1`
- Vesu Singleton: `0x3760f903a37948f97302736f89ce30290e45f441559325026842b7a6fb388c0`
- Ekubo Router V3: `0x0199741822c2dc722f6f605204f35e56dbc23bceed54818168c4c49e4fb8737e`
- WBTC: `0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac`
- USDC: `0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8`

## Commands
```bash
scarb build                    # Compile
snforge test                   # Run tests
sncast declare                 # Declare contract class
sncast deploy                  # Deploy instance
```

## Project Structure (target)
```
src/
├── lib.cairo                  # Module declarations
├── vault.cairo                # BitCoil contract (core)
├── interfaces/
│   ├── i_vault.cairo          # IBitCoil trait
│   ├── i_vesu.cairo           # IVesuSingleton trait
│   ├── i_ekubo.cairo          # IEkuboRouter trait
│   ├── i_pyth.cairo           # IPyth trait
│   └── i_erc20.cairo          # IERC20 trait
├── types.cairo                # Position struct, enums, events
└── utils.cairo                # Math helpers
tests/
├── test_vault.cairo
└── mocks/
    ├── mock_erc20.cairo
    ├── mock_lending.cairo
    └── mock_dex.cairo
```

## Development Rules
- **Commit after every milestone** with descriptive messages
- **Update this file** as phases complete (check off tasks below)
- Use `u256` for all financial amounts (not felt252)
- Pin all dependency versions
- Write tests alongside implementation

## Phase Progress

### Phase 1 — Setup + Cairo Basics
- [x] Install Starknet toolchain (starkup)
- [x] `scarb new bitcoil --test-runner=starknet-foundry`
- [x] Configure Scarb.toml with dependencies
- [x] Write hello world contract, verify snforge test passes
- [x] Study Vesu V2 and Ekubo interfaces

### Phase 2 — Interfaces + Types
- [x] Define interface traits (IBitCoil, IVesuSingleton, IFlashloanReceiver, IEkuboRouter, IERC20)
- [x] Define Position struct, error types, events
- [x] Write mock contracts (MockERC20, MockLending, MockDEX)
- [x] Implement basic vault storage + deposit()
- [x] Unit tests for deposit

### Phase 3 — Vesu Lending Integration
- [x] Implement lending_deposit() — vault deposits to Vesu
- [x] Implement lending_borrow() — vault borrows USDC
- [x] Single loop: deposit BTC → borrow USDC
- [x] Tests with mock lending

### Phase 4 — Swap Integration + Multi-Loop
- [x] Implement swap_stable_to_btc() via Ekubo
- [x] Full loop: deposit → borrow → swap → re-deposit
- [x] Multi-loop logic (N iterations)
- [x] Slippage protection
- [x] Tests for full loop

### Phase 5 — Unwind + Safety
- [x] unwind() — reverse the loop
- [x] full_unwind() — complete position closure
- [ ] Pyth Oracle integration for health factor (using stored price for now)
- [x] Safety: max loops, min health factor, pause
- [x] Events for all state changes
- [x] Edge case tests

### Phase 6 — Testnet Deployment
- [ ] Deploy to Starknet Sepolia
- [ ] Integration test against live/mock contracts

### Phase 7 — Testing + Hardening
- [ ] Edge cases, fuzz testing
- [ ] Security review
- [ ] Gas benchmarking

### Phase 8 — Frontend (Stretch)
- [ ] Next.js + starknet-react UI
- [ ] Xverse wallet integration

### Phase 9 — Submission
- [ ] Demo video (3 min)
- [ ] Final README
- [ ] Submit to DoraHacks

## Reference
- Full plan: `PLAN.md`
- Cairo Book: https://www.starknet.io/cairo-book/
- Starknet Foundry: https://foundry-rs.github.io/starknet-foundry/
- Vesu Docs: https://docs.vesu.xyz/developers
- Ekubo Docs: https://docs.ekubo.org/
- Pyth Docs: https://docs.pyth.network/price-feeds
