use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Position {
    pub deposited_amount: u256,
    pub total_collateral: u256,
    pub total_debt: u256,
    pub loop_count: u8,
    pub is_active: bool,
}

#[derive(Drop, starknet::Event)]
pub struct Deposited {
    #[key]
    pub user: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct LoopExecuted {
    #[key]
    pub user: ContractAddress,
    pub loop_number: u8,
    pub collateral_added: u256,
    pub debt_added: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Unwound {
    #[key]
    pub user: ContractAddress,
    pub loops_unwound: u8,
    pub collateral_withdrawn: u256,
    pub debt_repaid: u256,
}

#[derive(Drop, starknet::Event)]
pub struct FullyUnwound {
    #[key]
    pub user: ContractAddress,
    pub total_returned: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Paused {}

#[derive(Drop, starknet::Event)]
pub struct Unpaused {}

#[derive(Drop, starknet::Event)]
pub struct MaxLoopsUpdated {
    pub new_max: u8,
}

#[derive(Drop, starknet::Event)]
pub struct MinHealthFactorUpdated {
    pub new_factor: u256,
}

#[derive(Drop, starknet::Event)]
pub struct BtcPriceUpdated {
    pub new_price: u256,
}

pub mod Errors {
    pub const ZERO_AMOUNT: felt252 = 'Amount cannot be zero';
    pub const NOT_ACTIVE: felt252 = 'No active position';
    pub const ALREADY_ACTIVE: felt252 = 'Position already active';
    pub const TOO_MANY_LOOPS: felt252 = 'Exceeds max loops';
    pub const HEALTH_TOO_LOW: felt252 = 'Health factor too low';
    pub const PAUSED: felt252 = 'Contract is paused';
    pub const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    pub const TRANSFER_FAILED: felt252 = 'Token transfer failed';
    pub const SLIPPAGE_EXCEEDED: felt252 = 'Slippage exceeded';
}
