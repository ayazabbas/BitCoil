export const CONTRACTS = {
  VAULT: "0x01cb757dbf5e32fb7c2ee34b4bd1419ba9ffd350fcb857816b538cfbd25d09df",
  WBTC: "0x03d2d697e74d7fb157a3fe248e0e2a898a3f264733bf1ee1a5567bf8e6c86d3a",
  USDC: "0x04723e284d20811ee9d2d1542b440c39524010c43345a4804910ea8b68651b25",
} as const;

export const VAULT_ABI = [
  {
    name: "deposit_and_loop",
    type: "function",
    inputs: [
      { name: "amount", type: "core::integer::u256" },
      { name: "target_loops", type: "core::integer::u8" },
    ],
    outputs: [],
    state_mutability: "external",
  },
  {
    name: "unwind",
    type: "function",
    inputs: [{ name: "loops_to_unwind", type: "core::integer::u8" }],
    outputs: [],
    state_mutability: "external",
  },
  {
    name: "full_unwind",
    type: "function",
    inputs: [],
    outputs: [],
    state_mutability: "external",
  },
  {
    name: "get_position",
    type: "function",
    inputs: [{ name: "user", type: "core::starknet::contract_address::ContractAddress" }],
    outputs: [
      {
        type: "(core::integer::u256, core::integer::u256, core::integer::u256, core::integer::u8)",
      },
    ],
    state_mutability: "view",
  },
  {
    name: "get_health_factor",
    type: "function",
    inputs: [{ name: "user", type: "core::starknet::contract_address::ContractAddress" }],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
  {
    name: "get_effective_leverage",
    type: "function",
    inputs: [{ name: "user", type: "core::starknet::contract_address::ContractAddress" }],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
  {
    name: "owner",
    type: "function",
    inputs: [],
    outputs: [{ type: "core::starknet::contract_address::ContractAddress" }],
    state_mutability: "view",
  },
] as const;

export const ERC20_ABI = [
  {
    name: "approve",
    type: "function",
    inputs: [
      { name: "spender", type: "core::starknet::contract_address::ContractAddress" },
      { name: "amount", type: "core::integer::u256" },
    ],
    outputs: [{ type: "core::bool" }],
    state_mutability: "external",
  },
  {
    name: "balance_of",
    type: "function",
    inputs: [{ name: "account", type: "core::starknet::contract_address::ContractAddress" }],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
  {
    name: "allowance",
    type: "function",
    inputs: [
      { name: "owner", type: "core::starknet::contract_address::ContractAddress" },
      { name: "spender", type: "core::starknet::contract_address::ContractAddress" },
    ],
    outputs: [{ type: "core::integer::u256" }],
    state_mutability: "view",
  },
] as const;
