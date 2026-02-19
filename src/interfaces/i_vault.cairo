use starknet::ContractAddress;
use bitcoil::types::Position;

#[starknet::interface]
pub trait IBitCoil<TContractState> {
    // User functions
    fn deposit_and_loop(ref self: TContractState, amount: u256, target_loops: u8);
    fn unwind(ref self: TContractState, loops_to_unwind: u8);
    fn full_unwind(ref self: TContractState);

    // View functions
    fn get_position(self: @TContractState, user: ContractAddress) -> Position;
    fn get_health_factor(self: @TContractState, user: ContractAddress) -> u256;
    fn get_effective_leverage(self: @TContractState, user: ContractAddress) -> u256;

    // Admin functions
    fn set_max_loops(ref self: TContractState, max: u8);
    fn set_min_health_factor(ref self: TContractState, factor: u256);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
}
