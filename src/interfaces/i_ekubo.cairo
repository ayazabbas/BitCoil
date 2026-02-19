use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
pub struct RouteNode {
    pub pool_key: PoolKey,
    pub sqrt_ratio_limit: u256,
    pub skip_ahead: u128,
}

#[derive(Copy, Drop, Serde)]
pub struct PoolKey {
    pub token0: ContractAddress,
    pub token1: ContractAddress,
    pub fee: u128,
    pub tick_spacing: u128,
    pub extension: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
pub struct TokenAmount {
    pub token: ContractAddress,
    pub amount: i129,
}

#[derive(Copy, Drop, Serde)]
pub struct i129 {
    pub mag: u128,
    pub sign: bool,
}

#[starknet::interface]
pub trait IEkuboRouter<TContractState> {
    fn multihop_swap(
        ref self: TContractState, route: Array<RouteNode>, token_amount: TokenAmount,
    ) -> Array<TokenAmount>;
}
