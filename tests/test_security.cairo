use starknet::ContractAddress;
use starknet::contract_address_const;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};

use bitcoil::interfaces::i_vault::{IBitCoilDispatcher, IBitCoilDispatcherTrait};
use bitcoil::interfaces::i_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn USER() -> ContractAddress {
    contract_address_const::<'USER'>()
}

fn ATTACKER() -> ContractAddress {
    contract_address_const::<'ATTACKER'>()
}

fn deploy_mock_erc20(name: felt252, symbol: felt252, decimals: u8) -> ContractAddress {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata = array![name, symbol, decimals.into()];
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

fn mint_tokens(token: ContractAddress, to: ContractAddress, amount: u256) {
    start_cheat_caller_address(token, OWNER());
    let result = starknet::syscalls::call_contract_syscall(
        token, selector!("mint"), array![to.into(), amount.low.into(), amount.high.into()].span(),
    );
    assert(result.is_ok(), 'Mint failed');
    stop_cheat_caller_address(token);
}

fn deploy_mock_lending() -> ContractAddress {
    let contract = declare("MockLending").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    address
}

fn deploy_mock_dex(
    btc_token: ContractAddress, stable_token: ContractAddress, btc_price: u256,
) -> ContractAddress {
    let contract = declare("MockDEX").unwrap().contract_class();
    let mut calldata = array![];
    btc_token.serialize(ref calldata);
    stable_token.serialize(ref calldata);
    btc_price.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

fn setup() -> (ContractAddress, ContractAddress, ContractAddress) {
    let btc_token = deploy_mock_erc20('WBTC', 'WBTC', 8);
    let stable_token = deploy_mock_erc20('USDC', 'USDC', 6);
    let lending = deploy_mock_lending();
    let btc_price: u256 = 100_000_000_000;
    let dex = deploy_mock_dex(btc_token, stable_token, btc_price);

    mint_tokens(stable_token, lending, 1_000_000_000_000);
    mint_tokens(btc_token, lending, 1_000_000_000);
    mint_tokens(btc_token, dex, 1_000_000_000);
    mint_tokens(stable_token, dex, 1_000_000_000_000);

    let vault_contract = declare("BitCoil").unwrap().contract_class();
    let mut calldata = array![];
    OWNER().serialize(ref calldata);
    lending.serialize(ref calldata);
    calldata.append('POOL');
    dex.serialize(ref calldata);
    contract_address_const::<'PYTH'>().serialize(ref calldata);
    btc_token.serialize(ref calldata);
    stable_token.serialize(ref calldata);
    let feed_id: u256 = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
    feed_id.serialize(ref calldata);
    btc_price.serialize(ref calldata);

    let (vault_address, _) = vault_contract.deploy(@calldata).unwrap();
    (vault_address, btc_token, stable_token)
}

// --- Access Control Tests ---

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_pause() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, ATTACKER());
    vault.pause();
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_unpause() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, ATTACKER());
    vault.unpause();
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_set_max_loops() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, ATTACKER());
    vault.set_max_loops(10);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_set_health_factor() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, ATTACKER());
    vault.set_min_health_factor(200);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_set_btc_price() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, ATTACKER());
    vault.set_btc_price(200_000_000_000);
}

// --- Cannot unwind someone else's position ---

#[test]
#[should_panic(expected: 'No active position')]
fn test_cannot_unwind_others_position() {
    let (vault_address, btc_token, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    // USER deposits
    let amount: u256 = 100_000_000;
    mint_tokens(btc_token, USER(), amount);

    start_cheat_caller_address(btc_token, USER());
    IERC20Dispatcher { contract_address: btc_token }.approve(vault_address, amount);
    stop_cheat_caller_address(btc_token);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 0);
    stop_cheat_caller_address(vault_address);

    // ATTACKER tries to unwind USER's position
    start_cheat_caller_address(vault_address, ATTACKER());
    vault.full_unwind();
}

// --- Cannot operate when paused ---

#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_cannot_unwind_when_paused() {
    let (vault_address, btc_token, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    mint_tokens(btc_token, USER(), amount);

    start_cheat_caller_address(btc_token, USER());
    IERC20Dispatcher { contract_address: btc_token }.approve(vault_address, amount);
    stop_cheat_caller_address(btc_token);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 0);
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, OWNER());
    vault.pause();
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, USER());
    vault.full_unwind();
}

// --- View functions work for anyone ---

#[test]
fn test_anyone_can_view_position() {
    let (vault_address, btc_token, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    mint_tokens(btc_token, USER(), amount);

    start_cheat_caller_address(btc_token, USER());
    IERC20Dispatcher { contract_address: btc_token }.approve(vault_address, amount);
    stop_cheat_caller_address(btc_token);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 0);
    stop_cheat_caller_address(vault_address);

    // Attacker can read position (view function)
    let pos = vault.get_position(USER());
    assert(pos.is_active, 'Should see position');

    let hf = vault.get_health_factor(USER());
    assert(hf > 0, 'Should see health factor');

    let lev = vault.get_effective_leverage(USER());
    assert(lev == 100, 'Should see leverage');
}

// --- Deposit with insufficient approval fails ---

#[test]
#[should_panic(expected: 'Insufficient allowance')]
fn test_deposit_insufficient_allowance() {
    let (vault_address, btc_token, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    mint_tokens(btc_token, USER(), amount);

    // Approve less than deposit
    start_cheat_caller_address(btc_token, USER());
    IERC20Dispatcher { contract_address: btc_token }.approve(vault_address, amount / 2);
    stop_cheat_caller_address(btc_token);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 0);
}

// --- Deposit with insufficient balance fails ---

#[test]
#[should_panic(expected: 'Insufficient balance')]
fn test_deposit_insufficient_balance() {
    let (vault_address, btc_token, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    // Don't mint — user has 0 BTC

    start_cheat_caller_address(btc_token, USER());
    IERC20Dispatcher { contract_address: btc_token }.approve(vault_address, amount);
    stop_cheat_caller_address(btc_token);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 0);
}
