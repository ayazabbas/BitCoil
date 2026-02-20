# CLAUDE.md — BitCoil Frontend

## What This Is
Frontend for BitCoil — a BTC leverage looping vault on Starknet. Users connect wallet, deposit BTC, choose leverage (1-4x loops), and manage their position.

## Tech Stack
- **Framework**: Next.js 15 (App Router)
- **Wallet**: starknet-react + get-starknet (Argent X, Braavos)
- **UI**: shadcn/ui + Tailwind CSS v4
- **Language**: TypeScript (strict mode)
- **Chain interaction**: starknet.js v6

## Contract (Sepolia)
- **BitCoil Vault**: `0x01cb757dbf5e32fb7c2ee34b4bd1419ba9ffd350fcb857816b538cfbd25d09df`
- **WBTC (Mock)**: `0x03d2d697e74d7fb157a3fe248e0e2a898a3f264733bf1ee1a5567bf8e6c86d3a`
- **USDC (Mock)**: `0x04723e284d20811ee9d2d1542b440c39524010c43345a4804910ea8b68651b25`
- **Network**: Starknet Sepolia

## Key Contract Functions
```
deposit_and_loop(amount: u256, target_loops: u8)  — Deposit BTC + loop N times
unwind(loops_to_unwind: u8)                        — Partially unwind
full_unwind()                                      — Close entire position
get_position(user: ContractAddress) → Position     — Read position
get_health_factor(user: ContractAddress) → u256    — Read health
get_effective_leverage(user: ContractAddress) → u256
owner() → ContractAddress
```

## Pages
1. **Landing / Hero** — What is BitCoil, how it works, connect wallet CTA
2. **Dashboard** — Connected state: deposit form, position overview, leverage slider, health factor gauge, unwind buttons
3. **How It Works** — Visual explanation of the looping mechanism

## Design Direction
- Dark theme, crypto-native, premium DeFi dashboard feel
- BTC Orange (#F7931A) as primary accent on deep black/gray backgrounds
- Read `.claude/rules/components.md` for detailed design rules
- Read `.claude/skills/frontend-design/SKILL.md` for aesthetic guidelines

## Commands
```bash
npm run dev     # Start dev server
npm run build   # Production build
npm run lint    # Lint
npx playwright test  # E2E tests
```

## Rules
- Commit after every major milestone
- Test in browser after each component (run dev server)
- Mobile responsive — test at 375px, 768px, 1440px
- All contract calls should have loading states and error handling
- Use skeleton loaders while fetching chain data
