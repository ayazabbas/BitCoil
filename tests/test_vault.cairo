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

// Full setup with mock lending + mock dex
// Returns (vault, btc_token, stable_token, lending, dex)
fn setup_full() -> (
    ContractAddress, ContractAddress, ContractAddress, ContractAddress, ContractAddress,
) {
    let btc_token = deploy_mock_erc20('WBTC', 'WBTC', 8);
    let stable_token = deploy_mock_erc20('USDC', 'USDC', 6);

    let lending = deploy_mock_lending();
    // BTC price = 100,000 USDC (with 6 decimals = 100_000_000_000)
    let btc_price: u256 = 100_000_000_000; // 100k USDC in 6 decimals
    let dex = deploy_mock_dex(btc_token, stable_token, btc_price);

    // Fund MockLending with USDC for borrowing
    mint_tokens(stable_token, lending, 1_000_000_000_000); // 1M USDC
    // Fund MockLending with BTC for collateral returns
    mint_tokens(btc_token, lending, 1_000_000_000); // 10 BTC

    // Fund MockDEX with BTC for swaps (USDC->BTC)
    mint_tokens(btc_token, dex, 1_000_000_000); // 10 BTC
    // Fund MockDEX with USDC for swaps (BTC->USDC)
    mint_tokens(stable_token, dex, 1_000_000_000_000); // 1M USDC

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

    (vault_address, btc_token, stable_token, lending, dex)
}

// Simple setup for tests that don't need loops
fn setup_simple() -> (ContractAddress, ContractAddress, ContractAddress) {
    let (vault, btc, stable, _, _) = setup_full();
    (vault, btc, stable)
}

// Helper: mint BTC to user and approve vault
fn fund_user(btc_token: ContractAddress, vault: ContractAddress, amount: u256) {
    mint_tokens(btc_token, USER(), amount);
    start_cheat_caller_address(btc_token, USER());
    IERC20Dispatcher { contract_address: btc_token }.approve(vault, amount);
    stop_cheat_caller_address(btc_token);
}

// ==================== BASIC TESTS ====================

#[test]
fn test_deploy() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let position = vault.get_position(USER());
    assert(!position.is_active, 'Should not be active');
    assert(position.deposited_amount == 0, 'Should be 0');
}

#[test]
fn test_deposit_no_loops() {
    let (vault_address, btc_token, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };
    let btc = IERC20Dispatcher { contract_address: btc_token };

    let deposit_amount: u256 = 100_000_000; // 1 BTC (8 decimals)
    fund_user(btc_token, vault_address, deposit_amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(deposit_amount, 0);
    stop_cheat_caller_address(vault_address);

    let position = vault.get_position(USER());
    assert(position.is_active, 'Should be active');
    assert(position.deposited_amount == deposit_amount, 'Wrong deposit amount');
    assert(position.total_collateral == deposit_amount, 'Wrong collateral');
    assert(position.vesu_collateral == 0, 'Should have 0 in Vesu');
    assert(position.total_debt == 0, 'Should have no debt');
    assert(position.loop_count == 0, 'Should have 0 loops');

    assert(btc.balance_of(USER()) == 0, 'User should have 0 BTC');
    assert(btc.balance_of(vault_address) == deposit_amount, 'Vault should have BTC');
}

// ==================== LOOP TESTS ====================

#[test]
fn test_deposit_with_one_loop() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let deposit_amount: u256 = 100_000_000; // 1 BTC
    fund_user(btc_token, vault_address, deposit_amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(deposit_amount, 1);
    stop_cheat_caller_address(vault_address);

    let position = vault.get_position(USER());
    assert(position.is_active, 'Should be active');
    assert(position.loop_count == 1, 'Should have 1 loop');
    assert(position.total_collateral > deposit_amount, 'Collateral should increase');
    assert(position.total_debt > 0, 'Should have debt');

    // 1 BTC at $100k, borrow 65% = $65k, swap to 0.65 BTC
    // Total collateral = 1.0 + 0.65 = 1.65 BTC = 165M sats
    assert(position.total_collateral == 165_000_000, 'Expected 1.65 BTC');
    // Vesu has the initial 1 BTC deposit
    assert(position.vesu_collateral == 100_000_000, 'Expected 1 BTC in Vesu');
    // Debt: $65k USDC
    assert(position.total_debt == 65_000_000_000, 'Expected 65k USDC debt');
}

#[test]
fn test_deposit_with_two_loops() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let deposit_amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, deposit_amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(deposit_amount, 2);
    stop_cheat_caller_address(vault_address);

    let position = vault.get_position(USER());
    assert(position.loop_count == 2, 'Should have 2 loops');
    // After 2 loops: total = 1 + 0.65 + 0.4225 = 2.0725 BTC
    assert(position.total_collateral > 200_000_000, 'Should be >2 BTC');
    // Vesu has 1 + 0.65 = 1.65 BTC
    assert(position.vesu_collateral == 165_000_000, 'Expected 1.65 BTC in Vesu');
    assert(position.total_debt > 100_000_000_000, 'Should have >$100k debt');
}

#[test]
fn test_vesu_collateral_tracking_four_loops() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let deposit_amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, deposit_amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(deposit_amount, 4);
    stop_cheat_caller_address(vault_address);

    let position = vault.get_position(USER());
    assert(position.loop_count == 4, 'Should have 4 loops');
    // vesu_collateral should be less than total_collateral
    // (last swap result stays in vault)
    assert(position.vesu_collateral < position.total_collateral, 'Vesu < total');
    assert(position.vesu_collateral > 0, 'Vesu should be > 0');
    // vault_btc = total - vesu
    let vault_btc = position.total_collateral - position.vesu_collateral;
    assert(vault_btc > 0, 'Vault should hold some BTC');
}

// ==================== LEVERAGE & HEALTH ====================

#[test]
fn test_effective_leverage_with_loops() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let deposit_amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, deposit_amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(deposit_amount, 2);
    stop_cheat_caller_address(vault_address);

    let leverage = vault.get_effective_leverage(USER());
    assert(leverage > 100, 'Leverage should be > 1x');
    assert(leverage < 300, 'Leverage should be < 3x');
}

#[test]
fn test_health_factor_with_debt() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let deposit_amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, deposit_amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(deposit_amount, 1);
    stop_cheat_caller_address(vault_address);

    let hf = vault.get_health_factor(USER());
    assert(hf > 0, 'HF should be > 0');
}

#[test]
fn test_health_factor_after_one_loop() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 1);
    stop_cheat_caller_address(vault_address);

    let hf = vault.get_health_factor(USER());
    // After 1 loop: collateral = 1.65 BTC, debt = $65k
    // HF = (1.65 * $100k * 0.75) / $65k = 190.38
    // Scaled by 100 -> ~190
    assert(hf > 150, 'HF should be > 1.5');
    assert(hf < 250, 'HF should be < 2.5');
}

#[test]
fn test_health_factor_no_position() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let hf = vault.get_health_factor(USER());
    assert(hf == 0xFFFFFFFF_u256, 'Should be max for no position');
}

#[test]
fn test_leverage_increases_with_loops() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 1);
    stop_cheat_caller_address(vault_address);

    let lev1 = vault.get_effective_leverage(USER());
    // After 1 loop at 65% LTV: leverage = 1.65x -> 165 scaled by 100
    assert(lev1 == 165, 'Should be 1.65x');
}

// ==================== UNWIND TESTS ====================

#[test]
fn test_full_unwind_no_loops() {
    let (vault_address, btc_token, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };
    let btc = IERC20Dispatcher { contract_address: btc_token };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 0);
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, USER());
    vault.full_unwind();
    stop_cheat_caller_address(vault_address);

    let position = vault.get_position(USER());
    assert(!position.is_active, 'Should be inactive');
    assert(btc.balance_of(USER()) == amount, 'Should get BTC back');
}

#[test]
fn test_full_unwind_with_one_loop() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };
    let btc = IERC20Dispatcher { contract_address: btc_token };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 1);
    stop_cheat_caller_address(vault_address);

    let pos = vault.get_position(USER());
    assert(pos.loop_count == 1, 'Should have 1 loop');
    assert(pos.total_debt > 0, 'Should have debt');

    start_cheat_caller_address(vault_address, USER());
    vault.full_unwind();
    stop_cheat_caller_address(vault_address);

    let pos_after = vault.get_position(USER());
    assert(!pos_after.is_active, 'Should be inactive');
    assert(pos_after.total_debt == 0, 'Debt should be 0');

    // With perfect mock pricing, user gets back exactly 1 BTC
    let user_btc = btc.balance_of(USER());
    assert(user_btc == amount, 'Should get 1 BTC back');
}

#[test]
fn test_full_unwind_with_two_loops() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };
    let btc = IERC20Dispatcher { contract_address: btc_token };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 2);
    stop_cheat_caller_address(vault_address);

    let pos = vault.get_position(USER());
    assert(pos.loop_count == 2, 'Should have 2 loops');

    start_cheat_caller_address(vault_address, USER());
    vault.full_unwind();
    stop_cheat_caller_address(vault_address);

    let pos_after = vault.get_position(USER());
    assert(!pos_after.is_active, 'Should be inactive');

    // With perfect mock pricing, user gets back exactly 1 BTC
    let user_btc = btc.balance_of(USER());
    assert(user_btc == amount, 'Should get 1 BTC back');
}

#[test]
fn test_partial_unwind() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 2);
    stop_cheat_caller_address(vault_address);

    let pos_before = vault.get_position(USER());
    assert(pos_before.loop_count == 2, 'Should have 2 loops');

    // Unwind 1 loop
    start_cheat_caller_address(vault_address, USER());
    vault.unwind(1);
    stop_cheat_caller_address(vault_address);

    let pos_after = vault.get_position(USER());
    assert(pos_after.loop_count == 1, 'Should have 1 loop');
    assert(pos_after.is_active, 'Should still be active');
    assert(pos_after.total_debt < pos_before.total_debt, 'Debt should decrease');
    assert(pos_after.total_collateral < pos_before.total_collateral, 'Collateral should decrease');
    // Vesu collateral should match 1-loop state
    assert(pos_after.vesu_collateral == 100_000_000, 'Vesu should have 1 BTC');
}

#[test]
fn test_partial_unwind_then_full_unwind() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };
    let btc = IERC20Dispatcher { contract_address: btc_token };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 2);
    stop_cheat_caller_address(vault_address);

    // Partial unwind 1 loop
    start_cheat_caller_address(vault_address, USER());
    vault.unwind(1);
    stop_cheat_caller_address(vault_address);

    // Then full unwind the rest
    start_cheat_caller_address(vault_address, USER());
    vault.full_unwind();
    stop_cheat_caller_address(vault_address);

    let pos = vault.get_position(USER());
    assert(!pos.is_active, 'Should be inactive');
    let user_btc = btc.balance_of(USER());
    assert(user_btc == amount, 'Should get 1 BTC back');
}

// ==================== SAFETY / ADMIN TESTS ====================

#[test]
#[should_panic(expected: 'Amount cannot be zero')]
fn test_deposit_zero_amount() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(0, 0);
}

#[test]
#[should_panic(expected: 'Exceeds max loops')]
fn test_deposit_too_many_loops() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(100, 10);
}

#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_deposit_when_paused() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, OWNER());
    vault.pause();
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(100, 0);
}

#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_unwind_when_paused() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 1);
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, OWNER());
    vault.pause();
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, USER());
    vault.unwind(1);
}

#[test]
#[should_panic(expected: 'Contract is paused')]
fn test_full_unwind_when_paused() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 1);
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, OWNER());
    vault.pause();
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, USER());
    vault.full_unwind();
}

#[test]
fn test_pause_unpause() {
    let (vault_address, btc_token, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, OWNER());
    vault.pause();
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, OWNER());
    vault.unpause();
    stop_cheat_caller_address(vault_address);

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 0);
    stop_cheat_caller_address(vault_address);

    let position = vault.get_position(USER());
    assert(position.is_active, 'Should be active');
}

#[test]
fn test_set_max_loops() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, OWNER());
    vault.set_max_loops(8);
    stop_cheat_caller_address(vault_address);
}

#[test]
fn test_set_min_health_factor() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, OWNER());
    vault.set_min_health_factor(150);
    stop_cheat_caller_address(vault_address);
}

#[test]
fn test_set_btc_price() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, OWNER());
    vault.set_btc_price(150_000_000_000); // $150k
    stop_cheat_caller_address(vault_address);
}

#[test]
fn test_set_max_slippage_bps() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, OWNER());
    vault.set_max_slippage_bps(200); // 2%
    stop_cheat_caller_address(vault_address);
}

#[test]
#[should_panic(expected: 'Slippage exceeded')]
fn test_set_max_slippage_too_high() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, OWNER());
    vault.set_max_slippage_bps(2000); // 20% - should fail (max 10%)
}

#[test]
#[should_panic(expected: 'No active position')]
fn test_unwind_no_position() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, USER());
    vault.unwind(1);
}

#[test]
#[should_panic(expected: 'No active position')]
fn test_full_unwind_no_position() {
    let (vault_address, _, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    start_cheat_caller_address(vault_address, USER());
    vault.full_unwind();
}

#[test]
#[should_panic(expected: 'Position already active')]
fn test_double_deposit() {
    let (vault_address, btc_token, _) = setup_simple();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount * 2);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 0);
    vault.deposit_and_loop(amount, 0);
}

#[test]
#[should_panic(expected: 'Exceeds max loops')]
fn test_unwind_more_than_loop_count() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 1);
    stop_cheat_caller_address(vault_address);

    // Try to unwind 2 loops when only 1 exists
    start_cheat_caller_address(vault_address, USER());
    vault.unwind(2);
}

// ==================== POSITION STATE INVARIANTS ====================

#[test]
fn test_position_cleared_after_full_unwind() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 2);
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, USER());
    vault.full_unwind();
    stop_cheat_caller_address(vault_address);

    let pos = vault.get_position(USER());
    assert(!pos.is_active, 'Should be inactive');
    assert(pos.deposited_amount == 0, 'Deposit should be 0');
    assert(pos.total_collateral == 0, 'Collateral should be 0');
    assert(pos.vesu_collateral == 0, 'Vesu should be 0');
    assert(pos.total_debt == 0, 'Debt should be 0');
    assert(pos.loop_count == 0, 'Loops should be 0');
}

#[test]
fn test_can_deposit_again_after_full_unwind() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    // First deposit + loop
    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 1);
    stop_cheat_caller_address(vault_address);

    // Full unwind
    start_cheat_caller_address(vault_address, USER());
    vault.full_unwind();
    stop_cheat_caller_address(vault_address);

    // Should be able to deposit again
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 1);
    stop_cheat_caller_address(vault_address);

    let pos = vault.get_position(USER());
    assert(pos.is_active, 'Should be active again');
    assert(pos.loop_count == 1, 'Should have 1 loop');
}

#[test]
fn test_full_unwind_four_loops() {
    let (vault_address, btc_token, _, _, _) = setup_full();
    let vault = IBitCoilDispatcher { contract_address: vault_address };
    let btc = IERC20Dispatcher { contract_address: btc_token };

    let amount: u256 = 100_000_000;
    fund_user(btc_token, vault_address, amount);

    start_cheat_caller_address(vault_address, USER());
    vault.deposit_and_loop(amount, 4);
    stop_cheat_caller_address(vault_address);

    let pos = vault.get_position(USER());
    assert(pos.loop_count == 4, 'Should have 4 loops');

    start_cheat_caller_address(vault_address, USER());
    vault.full_unwind();
    stop_cheat_caller_address(vault_address);

    let pos_after = vault.get_position(USER());
    assert(!pos_after.is_active, 'Should be inactive');
    let user_btc = btc.balance_of(USER());
    assert(user_btc == amount, 'Should get 1 BTC back');
}
