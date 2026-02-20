# BTC Leverage Looping Vault on Starknet

## Comprehensive Development Plan

**Project:** BitCoil — Automated BTC Leverage Looping on Starknet
**Hackathon:** Starknet Re{define} Hackathon (Bitcoin Track)
**Deadline:** February 28, 2026, 23:59 UTC
**Prizes:** $9,675 STRK (Bitcoin Track) + $5,500 in-kind Xverse API (top 3 BTC projects)
**Submission:** DoraHacks BUIDL — GitHub repo + 3-min demo video + Starknet deployment
**Builder:** Solo dev, experienced in Solidity, new to Cairo

---

## 1. Concept

A smart contract vault on Starknet that automates **leverage looping** for BTC holders. Users deposit wrapped BTC, and the vault recursively:

1. Deposits BTC as collateral on Vesu V2 lending protocol
2. Borrows stablecoins (USDC) against it
3. Swaps stablecoins back to BTC via Ekubo DEX
4. Re-deposits the BTC as more collateral
5. Repeats N times

The result: leveraged long BTC exposure in a single transaction, powered by Starknet's native multicall and Vesu's zero-fee flash loans.

### Why Starknet?

- **Native multicall**: All accounts are smart contracts; multi-step loops execute atomically in one tx
- **BTCFi Season**: 100M STRK incentives program actively subsidizing BTC borrowing (effectively 0-1% APR after rewards)
- **Low gas**: ZK-rollup with cheap compute; each loop iteration costs fractions of a cent
- **Rich BTC ecosystem**: WBTC, SolvBTC, LBTC, tBTC all live with ~$130M+ TVL
- **Vesu free flash loans**: Zero-fee flash loans enable single-transaction leverage

### Why This Wins

- **Explicitly listed** as a desired Bitcoin track project idea ("leverage looping strategies", "BTC yield vaults")
- **No BTC projects have won** previous Starknet hackathons — fresh opportunity
- **Aligns with Starknet's core narrative** — they are branding as "The Bitcoin DeFi Layer"
- **Xverse integration** qualifies for additional $5,500 in-kind prizes

---

## 2. Architecture

### High-Level Flow

```
User (Xverse / Argent X / Braavos)
  │
  ▼
┌─────────────────────────────┐
│     BitCoil Contract    │
│                             │
│  deposit_and_loop()         │
│  ┌───────────────────────┐  │
│  │ Loop 1:               │  │
│  │  deposit BTC collat.  │──┼──► Vesu V2 (modify_position)
│  │  borrow USDC          │◄─┼──
│  │  swap USDC → BTC      │──┼──► Ekubo Router V3
│  │  receive BTC          │◄─┼──
│  ├───────────────────────┤  │
│  │ Loop 2: repeat...     │  │
│  ├───────────────────────┤  │
│  │ Loop N: repeat...     │  │
│  └───────────────────────┘  │
│                             │
│  unwind()                   │
│  emergency_deleverage()     │
│  get_health_factor() ───────┼──► Pyth Oracle (BTC/USD)
└─────────────────────────────┘
```

### Flash Loan Optimization (Stretch Goal)

```
Single Transaction:
1. Flash borrow X WBTC from Vesu (zero fee!)
2. Deposit ALL WBTC (user's + flash) as collateral
3. Borrow USDC against full collateral position
4. Swap USDC → WBTC via Ekubo
5. Repay flash loan
6. Result: Full leveraged position in ONE transaction
```

---

## 3. Smart Contract Design

### Contract Structure

```
src/
├── lib.cairo                    # Module declarations
├── vault.cairo                  # BitCoil contract (core)
├── interfaces/
│   ├── lib.cairo
│   ├── i_vault.cairo            # IBitCoil trait
│   ├── i_vesu.cairo             # IVesuSingleton trait
│   ├── i_ekubo.cairo            # IEkuboRouter trait
│   ├── i_pyth.cairo             # IPythOracle trait
│   └── i_erc20.cairo            # IERC20 trait
├── types.cairo                  # Position struct, enums, events
└── utils.cairo                  # Math helpers (leverage calc, health factor)
tests/
├── test_vault.cairo             # Integration tests
├── test_leverage_math.cairo     # Unit tests for math
└── mocks/
    ├── mock_lending.cairo       # Mock Vesu lending
    ├── mock_dex.cairo           # Mock Ekubo DEX
    └── mock_erc20.cairo         # Mock ERC20 token
scripts/
├── deploy.sh                   # Deployment script
└── interact.sh                 # Post-deployment interaction
frontend/                       # Next.js + starknet-react
```

### Core Contract: BitCoil

```
Storage:
  - owner: ContractAddress
  - vesu_singleton: ContractAddress     # Vesu V2 Singleton contract
  - pool_id: felt252                    # Vesu pool ID (Re7 xBTC)
  - ekubo_router: ContractAddress       # Ekubo Router V3
  - pyth_oracle: ContractAddress        # Pyth price feed
  - btc_token: ContractAddress          # WBTC
  - stable_token: ContractAddress       # USDC
  - positions: Map<ContractAddress, Position>
  - max_loops: u8                       # Default: 4
  - min_health_factor: u256             # Default: 1.15 (scaled by 100 → 115)
  - paused: bool

Position struct:
  - deposited_amount: u256     # Original BTC deposited by user
  - total_collateral: u256     # Total BTC collateral in Vesu
  - total_debt: u256           # Total USDC borrowed
  - loop_count: u8             # Number of loops executed
  - is_active: bool

External functions:
  - deposit_and_loop(amount: u256, target_loops: u8) → Position
  - unwind(loops_to_unwind: u8)
  - full_unwind()
  - get_position(user: ContractAddress) → Position
  - get_health_factor(user: ContractAddress) → u256
  - get_effective_leverage(user: ContractAddress) → u256

Owner functions:
  - set_max_loops(max: u8)
  - set_min_health_factor(factor: u256)
  - pause() / unpause()
```

### Interface Traits

```cairo
#[starknet::interface]
trait IBitCoil<TContractState> {
    fn deposit_and_loop(ref self: TContractState, amount: u256, target_loops: u8);
    fn unwind(ref self: TContractState, loops_to_unwind: u8);
    fn full_unwind(ref self: TContractState);
    fn get_position(self: @TContractState, user: ContractAddress) -> Position;
    fn get_health_factor(self: @TContractState, user: ContractAddress) -> u256;
    fn get_effective_leverage(self: @TContractState, user: ContractAddress) -> u256;
}

// Vesu V2 Singleton Interface
#[starknet::interface]
trait IVesuSingleton<TContractState> {
    fn modify_position(
        ref self: TContractState, params: ModifyPositionParams
    ) -> UpdatePositionResponse;
    fn flash_loan(
        ref self: TContractState,
        receiver: ContractAddress,
        asset: ContractAddress,
        amount: u256,
        is_legacy: bool,
        data: Span<felt252>,
    );
    fn ltv_config(
        self: @TContractState,
        pool_id: felt252,
        collateral_asset: ContractAddress,
        debt_asset: ContractAddress,
    ) -> LTVConfig;
    fn check_collateralization(
        self: @TContractState,
        pool_id: felt252,
        collateral_asset: ContractAddress,
        debt_asset: ContractAddress,
        user: ContractAddress,
    ) -> (bool, u256, u256);
}

// Flash loan callback — vault must implement this
#[starknet::interface]
trait IFlashloanReceiver<TContractState> {
    fn on_flash_loan(
        ref self: TContractState,
        sender: ContractAddress,
        asset: ContractAddress,
        amount: u256,
        data: Span<felt252>,
    );
}
```

---

## 4. Looping Mechanism — Step by Step

### Iterative Approach (MVP)

Starting with 1 WBTC ($100,000) at 65% LTV per loop:

| Loop | Action | Total Collateral | New Debt | Total Debt | Leverage | Health Factor |
|------|--------|-----------------|----------|------------|----------|---------------|
| 0 | Initial deposit | 1.000 WBTC | — | $0 | 1.00x | ∞ |
| 1 | Borrow $65K, buy 0.65 WBTC | 1.650 WBTC | $65,000 | $65,000 | 1.65x | 1.90 |
| 2 | Borrow $42.25K, buy 0.4225 WBTC | 2.073 WBTC | $42,250 | $107,250 | 2.07x | 1.45 |
| 3 | Borrow $27.46K, buy 0.2746 WBTC | 2.347 WBTC | $27,463 | $134,713 | 2.35x | 1.31 |
| 4 | Borrow $17.85K, buy 0.1785 WBTC | 2.526 WBTC | $17,853 | $152,566 | 2.53x | 1.24 |

**Safe max: 3-4 loops (~2.3-2.5x leverage)** to maintain health factor > 1.2

### Flash Loan Approach (Stretch Goal — Single Transaction)

1. User deposits 1 WBTC into vault
2. Vault flash borrows 1.35 WBTC from Vesu (zero fee)
3. Vault deposits ALL 2.35 WBTC as collateral in Vesu
4. Vault borrows ~$134,713 USDC against full collateral
5. Vault swaps USDC → 1.35 WBTC via Ekubo
6. Vault repays flash loan with 1.35 WBTC
7. Done — 2.35x leverage in one transaction

### Health Factor Formula

```
Health Factor = (Total Collateral in USD × Liquidation Threshold) / Total Debt in USD

At 2.35x leverage with 75% liquidation threshold:
HF = ($235,000 × 0.75) / $134,713 = 1.31

BTC price drop to trigger liquidation (HF = 1.0):
BTC must drop ~24% (from $100K to ~$76K)
```

### Leverage-to-Risk Table

| Leverage | Loops | Health Factor | Price Drop to Liquidation |
|----------|-------|---------------|---------------------------|
| 1.5x | 1 | 2.25 | -56% |
| 2.0x | 2 | 1.50 | -33% |
| 2.5x | 3 | 1.20 | -17% |
| 3.0x | 5 | 1.07 | -7% |
| 3.33x | ∞ | 1.00 | 0% (instant liquidation) |

**Default: 2.0x leverage (safe balance)**

Formula: `total_exposure = deposit × (1 - LTV^loops) / (1 - LTV)`

---

## 5. Tech Stack

| Component | Tool | Version |
|-----------|------|---------|
| Language | Cairo | 2.15+ |
| Build System | Scarb | 2.15+ |
| Testing | Starknet Foundry (snforge) | 0.38+ |
| Deployment | sncast | 0.38+ |
| CLI | Starkli | latest |
| Local Node | Katana (via Dojo) | latest |
| Libraries | OpenZeppelin Cairo | 0.20.0 |
| Oracle SDK | pyth (Starknet SDK) | latest |
| Frontend | Next.js + starknet-react | latest |
| Wallet (Starknet) | StarknetKit (Argent X, Braavos) | latest |
| Wallet (Bitcoin) | Sats Connect (Xverse) | latest |
| Network | Starknet Sepolia → Mainnet | — |

### Key Dependencies (Scarb.toml)

```toml
[package]
name = "bitcoil"
version = "0.1.0"
edition = "2024_07"

[dependencies]
starknet = ">=2.15.0"
openzeppelin_token = { git = "https://github.com/OpenZeppelin/cairo-contracts.git", tag = "v0.20.0" }
openzeppelin_access = { git = "https://github.com/OpenZeppelin/cairo-contracts.git", tag = "v0.20.0" }
# Pyth SDK - see https://docs.pyth.network/price-feeds for Starknet integration

[dev-dependencies]
snforge_std = { git = "https://github.com/foundry-rs/starknet-foundry", tag = "v0.38.0" }

[[target.starknet-contract]]
sierra = true
casm = true
```

---

## 6. DeFi Protocol Integrations

### 6.1 Vesu V2 (Lending/Borrowing) — PRIMARY

- **Role:** Collateral deposit, USDC borrowing, flash loans
- **Why Vesu:** Free flash loans, explicit BTCFi pools (Re7 xBTC), open-source contracts, $160M+ TVL
- **Why NOT zkLend:** Shut down June 2025 after $9.5M hack — defunct
- **BTC assets supported:** WBTC, LBTC, SolvBTC, tBTC
- **Effective borrow cost:** 0-1% after STRK rewards (BTCFi Season)
- **Integration:** `modify_position()` for supply/borrow, `flash_loan()` for atomic leverage
- **Docs:** https://docs.vesu.xyz/developers
- **GitHub:** https://github.com/vesuxyz

### 6.2 Nostra Finance — FALLBACK

- **Role:** Alternative lending if Vesu integration has issues
- **TVL:** ~$55M, largest on Starknet
- **Supports:** WBTC collateral, USDC/USDT/DAI borrowing
- **Token model:** iTokens (deposit receipts), dTokens (debt tracking)
- **Oracle:** Chainlink Price Feeds

### 6.3 Ekubo (DEX) — PRIMARY

- **Role:** Swap borrowed USDC → WBTC
- **Why Ekubo:** ~60% of Starknet AMM TVL, deepest liquidity, concentrated liquidity
- **WBTC/USDC:** ~$7M liquidity, ~$5.5M daily volume
- **Interface:** Lock/callback pattern or Router V3 for swaps
- **GitHub:** https://github.com/EkuboProtocol/starknet-contracts

### 6.4 AVNU — ALTERNATIVE DEX

- **Role:** DEX aggregator, routes across all Starknet AMMs
- **Advantage:** Best execution across multiple liquidity sources
- **Disadvantage:** On-chain integration may need off-chain quote — more complex

### 6.5 Pyth Network Oracle — PRIMARY

- **Role:** BTC/USD price feed for health factor calculation
- **BTC/USD Price Feed ID:** `0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43`
- **Price decimals:** variable (expo field in price struct)
- **Type:** Pull oracle (caller submits price update data)
- **Docs:** https://docs.pyth.network/price-feeds

### Key Contract Addresses

#### Mainnet

| Contract | Address |
|----------|---------|
| **WBTC** | `0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac` |
| **USDC (bridged)** | `0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8` |
| **USDT** | `0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8` |
| **ETH** | `0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7` |
| Vesu PoolFactory | `0x3760f903a37948f97302736f89ce30290e45f441559325026842b7a6fb388c0` |
| Vesu Oracle | `0xfe4bfb1b353ba51eb34dff963017f94af5a5cf8bdf3dfc191c504657f3c05` |
| Vesu Multiply | `0x7964760e90baa28841ec94714151e03fbc13321797e68a874e88f27c9d58513` |
| Vesu Liquidate | `0x6b895ba904fb8f02ed0d74e343161de48e611e9e771be4cc2c997501dbfb418` |
| Vesu Re7 xBTC Pool | `0x3a8416bf20d036df5b1cf3447630a2e1cb04685f6b0c3a70ed7fb1473548ecf` |
| Vesu Prime Pool | `0x451fe483d5921a2919ddd81d0de6696669bccdacd859f72a4fba7656b97c3b5` |
| Ekubo Core | `0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b` |
| Ekubo Router V3 | `0x0199741822c2dc722f6f605204f35e56dbc23bceed54818168c4c49e4fb8737e` |
| Pyth Oracle | `0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b` |

#### Sepolia Testnet

| Contract | Address |
|----------|---------|
| WBTC | `0x00452bd5c0512a61df7c7be8cfea5e4f893cb40e126bdc40aee6054db955129e` |
| WBTC L2 Bridge | `0x025a3820179262679392e872d7daaa44986af7caae1f41b7eedee561ca35a169` |

#### BTC Token Options (Mainnet)

| Token | Type | Address |
|-------|------|---------|
| WBTC | Wrapped BTC (BitGo) | `0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac` |
| tBTC | Threshold (decentralized) | `0x04daa17763b286d1e59b97c283c0b8c949994c361e426a28f743c67bdfe9a32f` |
| LBTC | Lombard Staked BTC | `0x036834a40984312f7f7de8d31e3f6305b325389eaeea5b1c0664b2fb936461a4` |
| SolvBTC | Solv Protocol | `0x0593e034dda23eea82d2ba9a30960ed42cf4a01502cc2351dc9b9881f9931a68` |

---

## 7. MVP vs Stretch Goals

### MVP (Must Have — Target Days 1-7)

- [ ] Cairo project setup with Scarb + Starknet Foundry
- [ ] `BitCoil` contract with `deposit_and_loop()`
- [ ] Vesu V2 integration (deposit collateral, borrow USDC via `modify_position`)
- [ ] Ekubo swap integration (USDC → WBTC)
- [ ] Iterative looping (deposit → borrow → swap → repeat N times)
- [ ] Position tracking per user (collateral, debt, leverage, loop count)
- [ ] `unwind()` — reverse the loop (repay → withdraw → swap → repeat)
- [ ] Health factor calculation via Pyth Oracle
- [ ] Safety: max loops, min health factor, pause
- [ ] Test suite with mock contracts (snforge)
- [ ] Sepolia testnet deployment
- [ ] 3-min demo video
- [ ] README with architecture + docs
- [ ] DoraHacks submission

### Stretch Goals

- [ ] Flash loan optimization (single-tx full leverage via Vesu flash loans)
- [ ] Xverse wallet integration via Sats Connect SDK (eligible for $5,500 in-kind)
- [ ] Simple frontend (Next.js + starknet-react + StarknetKit)
- [ ] Leverage slider UI with real-time health factor preview
- [ ] Auto-rebalance (deleverage when health factor drops below threshold)
- [ ] Multiple BTC asset support (WBTC, LBTC, SolvBTC)
- [ ] Mainnet deployment
- [ ] ERC-4626 vault shares for composability

### Anti-Scope (Explicitly Out)

- Liquidation bot infrastructure
- Multi-token vaults beyond BTC
- Governance token
- Yield farming / reward distribution
- Cross-chain bridging (user handles this pre-vault)

---

## 8. Development Phases

### Phase 1 — Setup + Cairo Basics
- [x] Initialize git repo
- [x] Research ecosystem, write PLAN.md and README.md
- [ ] Install Scarb, Starknet Foundry, Starkli
- [ ] `scarb new bitcoil --test-runner=starknet-foundry`
- [ ] Configure Scarb.toml (starknet, openzeppelin, pyth dependencies)
- [ ] Write first Cairo contract (hello world vault), run snforge test
- [ ] Study: Cairo ownership, storage, dispatchers, components
- [ ] Study: Vesu V2 source code on GitHub — understand `modify_position` interface
- [ ] Study: Ekubo swap interface — understand lock/callback or router pattern
- **Milestone:** Compiling project with passing tests

### Phase 2 — Interfaces + Types
- [ ] Define interface traits (IBitCoil, IVesuSingleton, IFlashloanReceiver, IEkuboRouter, IERC20)
- [ ] Define Position struct, error types, events
- [ ] Write mock contracts (MockERC20, MockLending, MockDEX)
- [ ] Implement basic vault storage (positions map, config)
- [ ] Implement `deposit()` — accept WBTC, store position
- [ ] Write unit tests for deposit
- **Milestone:** Vault accepts deposits, stores positions, tests pass

### Phase 3 — Vesu Lending Integration
- [ ] Study Vesu V2 contract ABI (from Starkscan or GitHub)
- [ ] Implement `lending_deposit()` — vault deposits to Vesu pool
- [ ] Implement `lending_borrow()` — vault borrows USDC from Vesu
- [ ] Wire up single loop: deposit BTC → borrow USDC
- [ ] Test with mock lending protocol
- **Milestone:** Single deposit-borrow cycle works against mocks

### Phase 4 — Swap Integration + Multi-Loop
- [ ] Study Ekubo Router V3 interface
- [ ] Implement `swap_stable_to_btc()` — swap USDC for WBTC via Ekubo
- [ ] Complete full loop: deposit → borrow → swap → re-deposit
- [ ] Implement multi-loop logic (loop N times)
- [ ] Add slippage protection on swaps
- [ ] Test full loop with mocks
- **Milestone:** Full N-loop cycle works against mocks

### Phase 5 — Unwind + Safety
- [ ] Implement `unwind()` — reverse loop (withdraw → repay → swap → repeat)
- [ ] Implement `full_unwind()` — complete position closure
- [ ] Integrate Pyth Oracle for BTC/USD price
- [ ] Implement `get_health_factor()` using oracle price
- [ ] Add safety checks (max loops, min health factor, pause/unpause)
- [ ] Add events for all state changes
- [ ] Comprehensive test suite for edge cases
- **Milestone:** Full loop + unwind cycle, safety mechanisms, all tests pass

### Phase 6 — Testnet Deployment
- [x] Install starknet-devnet v0.7.2 for local testing
- [x] Create and configure deployment accounts (devnet + Sepolia)
- [x] Declare all contracts (BitCoil, MockERC20, MockLending, MockDEX)
- [x] Deploy mock contracts (WBTC, USDC, MockLending, MockDEX) on devnet
- [x] Deploy BitCoil vault with full constructor args on devnet
- [x] Verify deployment: get_position, get_health_factor, owner calls pass
- [x] Write deployment scripts: scripts/deploy_devnet.sh, scripts/deploy_sepolia.sh
- [ ] Deploy to Sepolia (requires manual faucet funding at https://starknet-faucet.vercel.app/)
- **Milestone:** Working deployment on devnet, deployment scripts ready for Sepolia

### Phase 7 — Testing + Hardening
- [ ] Edge case testing (max leverage, zero amounts, insufficient balance)
- [ ] Security review (reentrancy, overflow, access control)
- [ ] Fuzz testing for leverage calculations
- [ ] Gas benchmarking
- [ ] Fix all bugs found
- **Milestone:** Hardened, well-tested contract

### Phase 8 — Frontend + Polish (Stretch)
- [ ] Simple frontend (Next.js + starknet-react)
- [ ] Xverse wallet integration (Sats Connect)
- [ ] Flash loan optimization
- [ ] Clean up code, add comments
- [ ] Finalize README
- **Milestone:** Polished project with frontend

### Phase 9 — Submission
- [ ] Record 3-min demo video (full loop cycle walkthrough)
- [ ] Final README review, ensure all diagrams are clear
- [ ] Submit on DoraHacks (GitHub, video, deployment link)
- **Milestone:** SUBMITTED

---

## 9. Cairo Patterns for Solidity Devs

### Quick Reference

| Concept | Solidity | Cairo |
|---------|----------|-------|
| External calls | `IERC20(addr).transfer(...)` | `IERC20Dispatcher { contract_address: addr }.transfer(...)` |
| msg.sender | `msg.sender` | `get_caller_address()` |
| Storage mapping | `mapping(address => uint)` | `Map<ContractAddress, u256>` |
| Events | `emit Transfer(...)` | `self.emit(Transfer { ... })` |
| Require/revert | `require(x > 0, "msg")` | `assert(x > 0, 'error msg')` |
| Visibility | `external`/`public` | `#[abi(embed_v0)] impl` |
| Inheritance | `is Ownable` | `component!(path: OwnableComponent, ...)` |
| View vs mutate | `view` / no modifier | `self: @TContractState` / `ref self: TContractState` |
| Integers | `uint256` | `u256` (two u128s internally) |
| Deploy | Single tx | `declare` (class) then `deploy` (instance) |

### Key Gotchas

1. **No dynamic arrays in storage** — use `Map<u32, T>` with a length counter
2. **felt252 is 251 bits**, not 256 — use u256 for financial amounts
3. **Two-step deployment** — declare class hash first, then deploy instance
4. **Interface traits generate dispatchers** — `IFoo` → `IFooDispatcher` + `IFooDispatcherTrait`
5. **Components, not inheritance** — use `component!()` macro
6. **Storage reads/writes are explicit** — `self.balance.read()` / `self.balance.write(value)`
7. **All accounts are smart contracts** — native Account Abstraction, no EOAs
8. **Goerli is deprecated** — use **Sepolia** testnet only

---

## 10. Risk Management

### Health Factor Monitoring

```
SAFE ZONE (HF > 1.5):      No action needed
WARNING ZONE (1.3-1.5):     Alert user, suggest deleverage
DANGER ZONE (1.1-1.3):      Auto-deleverage (stretch goal)
CRITICAL (HF < 1.1):        Emergency full unwind
LIQUIDATION (HF ≤ 1.0):     Protocol liquidates — user loses collateral
```

**Recommended defaults:**
- Max leverage: 2.5x (conservative for hackathon)
- Target health factor: 1.5
- Min health factor for new loops: 1.2
- LTV per loop: 65% (below Vesu max for safety buffer)

### Smart Contract Risks

| Risk | Mitigation |
|------|-----------|
| Reentrancy | Cairo's ownership model helps; checks-effects-interactions pattern |
| Oracle manipulation | Use Pyth confidence intervals; add staleness check (max 5 min age) |
| Integer overflow | Cairo has built-in overflow checking |
| Unauthorized access | OwnableComponent for admin; positions isolated per user |
| Flash loan attack | We use flash loans defensively; oracle is external |

### DeFi Protocol Risks

| Risk | Mitigation |
|------|-----------|
| Vesu exploit | Emergency pause; Nostra as fallback (stretch) |
| Ekubo low liquidity | Min output amounts; slippage protection |
| WBTC depeg | Monitor ratio; emergency unwind if > 2% deviation |
| Cascading liquidations | Conservative 2.0x default leverage |

### Hackathon-Specific Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Cairo learning curve | Slow development | Cairo Book + Starknet by Example; mock contracts heavily |
| Vesu/Ekubo not on Sepolia | Can't do live integration test | Deploy mock contracts; test logic independently |
| Tooling issues | Blocked on setup | Katana local node first; Sepolia as secondary |
| Time crunch | Incomplete submission | Strict MVP scope; iterative looping first, flash loans later |
| Demo fails | Poor impression | Pre-record demo; have tx hashes as backup |

---

## 11. Competitive Analysis

| Project | What It Does | Our Differentiation |
|---------|-------------|-------------------|
| **Vesu Multiply** | Built-in one-click leverage | We're a vault wrapper — custom strategies, configurable leverage, vault shares |
| **Troves.fi** | Automated looping vaults | We add Xverse BTC-native entry, health factor UI, open-source |
| **Re7 Labs** | Market-neutral BTC yield | Different strategy — directional leverage vs market-neutral |
| **Endur.fi** | BTC liquid staking | Complementary — users could loop with Endur's xWBTC |

### Our Edge

1. **Open-source vault** — transparent, composable, forkable
2. **Xverse integration** — native Bitcoin wallet users can enter directly
3. **Configurable leverage** — users choose 1.5x to 3x, not a fixed strategy
4. **Educational** — health factor UI teaches users about risk
5. **Protocol-agnostic design** — can add Nostra or other lending backends

---

## 12. Submission Checklist

### DoraHacks BUIDL Requirements

- [ ] **GitHub repo** (public) with clean code
- [ ] **Demo video** ≤ 3 minutes showing:
  - [ ] Wallet connection
  - [ ] WBTC deposit into vault
  - [ ] Looping execution (leverage increasing)
  - [ ] Health factor display
  - [ ] Position withdrawal / unwind
- [ ] **Starknet deployment link** (Sepolia minimum, mainnet ideal)
- [ ] **Project description** on DoraHacks page

### Xverse Prize Eligibility

- [ ] Integrate Xverse wallet via Sats Connect SDK
- [ ] Show BTC-to-Starknet flow using Xverse
- [ ] Document Xverse integration in README

### Judging Criteria Optimization

| Criterion | Weight | Our Approach |
|-----------|--------|-------------|
| Commercial Value | 20% | Real DeFi use case — leverage is top-demanded; BTC holders want yield without selling |
| Innovation | 20% | One-click vault leverage on L2; flash-loan-optimized; Xverse BTC-native entry |
| Technical Depth | 40%+ | Cairo contracts, multi-protocol composability (Vesu + Ekubo + Pyth), ERC-4626 |
| UX | 10% | Simple deposit UI, leverage slider, health factor visualization |
| Impact | 10% | Expands BTCFi ecosystem; aligns with 100M STRK incentive program |

---

## 13. Open Questions (Resolve Day 1)

1. **Vesu on Sepolia?** — Are Vesu contracts deployed on Sepolia testnet? If not, need mock contracts.
2. **Ekubo on Sepolia?** — Same question. Check Ekubo docs.
3. **Vesu `modify_position` exact ABI** — Need precise function signature. Read GitHub source.
4. **Ekubo swap pattern** — Lock/callback vs direct router swap? Read Ekubo source.
5. **WBTC Sepolia faucet** — Can we get test WBTC? May need to deploy mock ERC20.
6. **Which USDC?** — Bridged USDC.e or native USDC? Check which Vesu accepts.

---

## 14. Key Resources

| Resource | URL |
|----------|-----|
| Cairo Book | https://www.starknet.io/cairo-book/ |
| Starknet by Example | https://starknet-by-example.voyager.online/ |
| Starknet Foundry Book | https://foundry-rs.github.io/starknet-foundry/ |
| OZ Cairo Contracts | https://docs.openzeppelin.com/contracts-cairo/ |
| OZ Wizard | https://wizard.openzeppelin.com/ |
| Vesu Developer Docs | https://docs.vesu.xyz/developers |
| Vesu GitHub | https://github.com/vesuxyz |
| Ekubo GitHub | https://github.com/EkuboProtocol/starknet-contracts |
| Ekubo Docs | https://docs.ekubo.org/ |
| Pyth Docs | https://docs.pyth.network/price-feeds |
| Pyth Starknet | https://docs.pyth.network/price-feeds/core/contract-addresses/starknet |
| starknet.js Docs | https://starknetjs.com/ |
| starknet-react | https://starknet-react.com/ |
| Sats Connect (Xverse) | https://docs.xverse.app/sats-connect |
| Re{define} Hackathon | https://dorahacks.io/hackathon/redefine |
| Starknet Faucet | https://starknet-faucet.vercel.app/ |
| Starkscan Explorer | https://starkscan.co/ |
| Sepolia Explorer | https://sepolia.starkscan.co/ |
| BTCFi Season | https://btcfiseason.starknet.org/ |
| Looping Deep Dive | https://medium.com/contango-xyz/what-is-looping-78421c8a1367 |
| Starknet BTC Yield Guide | https://www.starknet.io/blog/bitcoin-yield/ |
| BitcoinFi on Starknet | https://www.xverse.app/blog/bitcoinfi-on-starknet |

### Expert Support (AMA Sessions)

| Expert | Focus |
|--------|-------|
| Adrien Lacombe (Bitcoin Lead) | BTCFi strategies |
| Benjamin Sturisky (DeFi Expert) | Strategy & tokenomics |
| Akash Balasubramani (StarkWare) | Cairo & ZK engineering |
