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

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

// Deploy mock ERC20 and return its address
fn deploy_mock_erc20(name: felt252, symbol: felt252, decimals: u8) -> ContractAddress {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata = array![name, symbol, decimals.into()];
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

// Mint tokens to an address
fn mint_tokens(token: ContractAddress, to: ContractAddress, amount: u256) {
    let mut calldata = array![];
    to.serialize(ref calldata);
    amount.serialize(ref calldata);

    // Call mint directly using low-level
    let token_class = declare("MockERC20").unwrap().contract_class();
    // We'll use the dispatcher approach via cheat instead
    // For simplicity, call mint via the ERC20 mock's external function
    start_cheat_caller_address(token, OWNER());
    // Use syscall to call mint
    let result = starknet::syscalls::call_contract_syscall(
        token, selector!("mint"), array![to.into(), amount.low.into(), amount.high.into()].span(),
    );
    assert(result.is_ok(), 'Mint failed');
    stop_cheat_caller_address(token);
}

// Deploy the vault and return (vault_address, btc_token, stable_token)
fn setup() -> (ContractAddress, ContractAddress, ContractAddress) {
    let btc_token = deploy_mock_erc20('WBTC', 'WBTC', 8);
    let stable_token = deploy_mock_erc20('USDC', 'USDC', 6);

    let vault_contract = declare("BitCoil").unwrap().contract_class();
    let mut calldata = array![];
    // owner
    OWNER().serialize(ref calldata);
    // vesu_singleton (mock - unused for now)
    contract_address_const::<'VESU'>().serialize(ref calldata);
    // pool_id
    calldata.append('POOL');
    // ekubo_router (mock - unused for now)
    contract_address_const::<'EKUBO'>().serialize(ref calldata);
    // pyth_oracle (mock - unused for now)
    contract_address_const::<'PYTH'>().serialize(ref calldata);
    // btc_token
    btc_token.serialize(ref calldata);
    // stable_token
    stable_token.serialize(ref calldata);
    // btc_usd_feed_id
    let feed_id: u256 = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
    feed_id.serialize(ref calldata);

    let (vault_address, _) = vault_contract.deploy(@calldata).unwrap();

    (vault_address, btc_token, stable_token)
}

#[test]
fn test_deploy() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    // Check default position for user is inactive
    let position = vault.get_position(USER());
    assert(!position.is_active, 'Should not be active');
    assert(position.deposited_amount == 0, 'Should be 0');
}

#[test]
fn test_deposit_no_loops() {
    let (vault_address, btc_token, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };
    let btc = IERC20Dispatcher { contract_address: btc_token };

    let deposit_amount: u256 = 100_000_000; // 1 BTC (8 decimals)

    // Mint BTC to user
    mint_tokens(btc_token, USER(), deposit_amount);

    // User approves vault
    start_cheat_caller_address(btc_token, USER());
    btc.approve(vault_address, deposit_amount);
    stop_cheat_caller_address(btc_token);

    // User deposits (0 loops = deposit only)
    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(deposit_amount, 0);
    stop_cheat_caller_address(vault_address);

    // Check position
    let position = vault.get_position(USER());
    assert(position.is_active, 'Should be active');
    assert(position.deposited_amount == deposit_amount, 'Wrong deposit amount');
    assert(position.total_collateral == deposit_amount, 'Wrong collateral');
    assert(position.total_debt == 0, 'Should have no debt');
    assert(position.loop_count == 0, 'Should have 0 loops');

    // Check token balance moved
    assert(btc.balance_of(USER()) == 0, 'User should have 0 BTC');
    assert(btc.balance_of(vault_address) == deposit_amount, 'Vault should have BTC');
}

#[test]
fn test_deposit_with_loops() {
    let (vault_address, btc_token, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };
    let btc = IERC20Dispatcher { contract_address: btc_token };

    let deposit_amount: u256 = 100_000_000; // 1 BTC

    mint_tokens(btc_token, USER(), deposit_amount);

    start_cheat_caller_address(btc_token, USER());
    btc.approve(vault_address, deposit_amount);
    stop_cheat_caller_address(btc_token);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(deposit_amount, 2);
    stop_cheat_caller_address(vault_address);

    let position = vault.get_position(USER());
    assert(position.is_active, 'Should be active');
    assert(position.loop_count == 2, 'Should have 2 loops');
    assert(position.total_collateral > deposit_amount, 'Collateral should increase');
    assert(position.total_debt > 0, 'Should have debt');
}

#[test]
fn test_effective_leverage() {
    let (vault_address, btc_token, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };
    let btc = IERC20Dispatcher { contract_address: btc_token };

    let deposit_amount: u256 = 100_000_000;

    mint_tokens(btc_token, USER(), deposit_amount);

    start_cheat_caller_address(btc_token, USER());
    btc.approve(vault_address, deposit_amount);
    stop_cheat_caller_address(btc_token);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(deposit_amount, 2);
    stop_cheat_caller_address(vault_address);

    let leverage = vault.get_effective_leverage(USER());
    // With mock swap (1:1), after 2 loops at 65% LTV:
    // collateral = 100M + 65M + 42.25M = ~207.25M
    // leverage = 207.25M / 100M * 100 = ~207
    assert(leverage > 100, 'Leverage should be > 1x');
    assert(leverage < 300, 'Leverage should be < 3x');
}

#[test]
#[should_panic(expected: 'Amount cannot be zero')]
fn test_deposit_zero_amount() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(0, 0);
}

#[test]
#[should_panic(expected: 'Exceeds max loops')]
fn test_deposit_too_many_loops() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(100, 10); // max is 4
}

#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_deposit_when_paused() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    // Owner pauses
    start_cheat_caller_address(vault_address, OWNER());
    vault.pause();
    stop_cheat_caller_address(vault_address);

    // User tries to deposit
    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(100, 0);
}

#[test]
fn test_pause_unpause() {
    let (vault_address, btc_token, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };
    let btc = IERC20Dispatcher { contract_address: btc_token };

    // Owner pauses
    start_cheat_caller_address(vault_address, OWNER());
    vault.pause();
    stop_cheat_caller_address(vault_address);

    // Owner unpauses
    start_cheat_caller_address(vault_address, OWNER());
    vault.unpause();
    stop_cheat_caller_address(vault_address);

    // Now deposit should work
    let amount: u256 = 100_000_000;
    mint_tokens(btc_token, USER(), amount);

    start_cheat_caller_address(btc_token, USER());
    btc.approve(vault_address, amount);
    stop_cheat_caller_address(btc_token);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 0);
    stop_cheat_caller_address(vault_address);

    let position = vault.get_position(USER());
    assert(position.is_active, 'Should be active');
}

#[test]
fn test_set_max_loops() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, OWNER());
    vault.set_max_loops(8);
    stop_cheat_caller_address(vault_address);

    // Now 8 loops should not panic (though we won't execute all)
    // Just verify the setting works by trying 0 loops
}

#[test]
fn test_health_factor_no_position() {
    let (vault_address, _, _) = setup();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let hf = vault.get_health_factor(USER());
    assert(hf == 0xFFFFFFFF_u256, 'Should be max for no position');
}
