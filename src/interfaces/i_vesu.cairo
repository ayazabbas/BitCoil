use starknet::ContractAddress;

// Vesu V2 modify_position parameters
#[derive(Copy, Drop, Serde)]
pub struct ModifyPositionParams {
    pub pool_id: felt252,
    pub collateral_asset: ContractAddress,
    pub debt_asset: ContractAddress,
    pub user: ContractAddress,
    pub collateral: Amount,
    pub debt: Amount,
    pub data: Span<felt252>,
}

#[derive(Copy, Drop, Serde)]
pub struct Amount {
    pub amount_type: AmountType,
    pub denomination: AmountDenomination,
    pub value: i257,
}

#[derive(Copy, Drop, Serde)]
pub enum AmountType {
    Delta,
    Target,
}

#[derive(Copy, Drop, Serde)]
pub enum AmountDenomination {
    Native,
    Assets,
}

// i257: signed 257-bit integer used by Vesu
#[derive(Copy, Drop, Serde)]
pub struct i257 {
    pub abs: u256,
    pub is_negative: bool,
}

#[derive(Copy, Drop, Serde)]
pub struct UpdatePositionResponse {
    pub collateral_delta: i257,
    pub debt_delta: i257,
}

#[derive(Copy, Drop, Serde)]
pub struct LTVConfig {
    pub max_ltv: u64,
}

#[starknet::interface]
pub trait IVesuSingleton<TContractState> {
    fn modify_position(
        ref self: TContractState, params: ModifyPositionParams,
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

#[starknet::interface]
pub trait IFlashloanReceiver<TContractState> {
    fn on_flash_loan(
        ref self: TContractState,
        sender: ContractAddress,
        asset: ContractAddress,
        amount: u256,
        data: Span<felt252>,
    );
}
