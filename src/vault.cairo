#[starknet::contract]
pub mod BitCoil {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use openzeppelin_access::ownable::OwnableComponent;

    use bitcoil::types::{
        Position, Errors, Deposited, LoopExecuted, Unwound, FullyUnwound, Paused, Unpaused,
        MaxLoopsUpdated, MinHealthFactorUpdated, BtcPriceUpdated, SlippageUpdated,
    };
    use bitcoil::interfaces::i_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use bitcoil::interfaces::i_vesu::{
        IVesuSingletonDispatcher, IVesuSingletonDispatcherTrait, ModifyPositionParams, Amount,
        AmountType, AmountDenomination, i257,
    };
    use bitcoil::interfaces::i_ekubo::{
        IEkuboRouterDispatcher, IEkuboRouterDispatcherTrait, RouteNode, PoolKey, TokenAmount, i129,
    };
    use bitcoil::interfaces::i_pyth::{IPythDispatcher, IPythDispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        vesu_singleton: ContractAddress,
        pool_id: felt252,
        ekubo_router: ContractAddress,
        pyth_oracle: ContractAddress,
        btc_token: ContractAddress,
        stable_token: ContractAddress,
        positions: Map<ContractAddress, Position>,
        max_loops: u8,
        min_health_factor: u256,
        paused: bool,
        btc_usd_feed_id: u256,
        // BTC price in stable token units (e.g., 100_000_000_000 = $100k with 6 USDC decimals)
        // Will be replaced with oracle reads in Phase 5
        btc_price: u256,
        // Max slippage in basis points (e.g., 100 = 1%)
        max_slippage_bps: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        Deposited: Deposited,
        LoopExecuted: LoopExecuted,
        Unwound: Unwound,
        FullyUnwound: FullyUnwound,
        Paused: Paused,
        Unpaused: Unpaused,
        MaxLoopsUpdated: MaxLoopsUpdated,
        MinHealthFactorUpdated: MinHealthFactorUpdated,
        BtcPriceUpdated: BtcPriceUpdated,
        SlippageUpdated: SlippageUpdated,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        vesu_singleton: ContractAddress,
        pool_id: felt252,
        ekubo_router: ContractAddress,
        pyth_oracle: ContractAddress,
        btc_token: ContractAddress,
        stable_token: ContractAddress,
        btc_usd_feed_id: u256,
        btc_price: u256,
    ) {
        self.ownable.initializer(owner);
        self.vesu_singleton.write(vesu_singleton);
        self.pool_id.write(pool_id);
        self.ekubo_router.write(ekubo_router);
        self.pyth_oracle.write(pyth_oracle);
        self.btc_token.write(btc_token);
        self.stable_token.write(stable_token);
        self.btc_usd_feed_id.write(btc_usd_feed_id);
        self.btc_price.write(btc_price);
        self.max_loops.write(4);
        // 115 = 1.15 scaled by 100
        self.min_health_factor.write(115);
        // 100 bps = 1% default slippage
        self.max_slippage_bps.write(100);
        self.paused.write(false);
    }

    #[abi(embed_v0)]
    impl BitCoilImpl of bitcoil::interfaces::i_vault::IBitCoil<ContractState> {
        fn deposit_and_loop(ref self: ContractState, amount: u256, target_loops: u8) {
            self.assert_not_paused();
            assert(amount > 0, Errors::ZERO_AMOUNT);
            assert(target_loops <= self.max_loops.read(), Errors::TOO_MANY_LOOPS);

            let caller = get_caller_address();
            let position = self.positions.entry(caller).read();
            assert(!position.is_active, Errors::ALREADY_ACTIVE);

            // Transfer BTC from user to vault
            let btc = IERC20Dispatcher { contract_address: self.btc_token.read() };
            let success = btc.transfer_from(caller, get_contract_address(), amount);
            assert(success, Errors::TRANSFER_FAILED);

            // Initialize position
            let new_position = Position {
                deposited_amount: amount,
                total_collateral: amount,
                vesu_collateral: 0,
                total_debt: 0,
                loop_count: 0,
                is_active: true,
            };
            self.positions.entry(caller).write(new_position);

            self.emit(Deposited { user: caller, amount });

            // Execute loops
            if target_loops > 0 {
                self.execute_loops(caller, target_loops);
            }
        }

        fn unwind(ref self: ContractState, loops_to_unwind: u8) {
            self.assert_not_paused();
            let caller = get_caller_address();
            let position = self.positions.entry(caller).read();
            assert(position.is_active, Errors::NOT_ACTIVE);
            assert(loops_to_unwind <= position.loop_count, Errors::TOO_MANY_LOOPS);

            self.execute_unwind(caller, loops_to_unwind);
        }

        fn full_unwind(ref self: ContractState) {
            self.assert_not_paused();
            let caller = get_caller_address();
            let position = self.positions.entry(caller).read();
            assert(position.is_active, Errors::NOT_ACTIVE);

            let had_loops = position.loop_count > 0;
            if had_loops {
                self.execute_unwind(caller, position.loop_count);
            }

            let btc = IERC20Dispatcher { contract_address: self.btc_token.read() };
            let this = get_contract_address();
            let position = self.positions.entry(caller).read();

            if had_loops {
                // After unwind: vault has some BTC, Vesu has remaining collateral
                if position.vesu_collateral > 0 {
                    self.withdraw_from_vesu(position.vesu_collateral);
                }
            }

            // Return all vault BTC to user
            let vault_btc_balance = btc.balance_of(this);
            if vault_btc_balance > 0 {
                btc.transfer(caller, vault_btc_balance);
            }

            // Clear position
            self.positions.entry(caller).write(Position {
                deposited_amount: 0,
                total_collateral: 0,
                vesu_collateral: 0,
                total_debt: 0,
                loop_count: 0,
                is_active: false,
            });

            self.emit(FullyUnwound { user: caller, total_returned: vault_btc_balance });
        }

        fn get_position(self: @ContractState, user: ContractAddress) -> Position {
            self.positions.entry(user).read()
        }

        fn get_health_factor(self: @ContractState, user: ContractAddress) -> u256 {
            let position = self.positions.entry(user).read();
            if !position.is_active || position.total_debt == 0 {
                return 0xFFFFFFFF_u256; // Max value = infinite health
            }
            self.calculate_health_factor(position)
        }

        fn get_effective_leverage(self: @ContractState, user: ContractAddress) -> u256 {
            let position = self.positions.entry(user).read();
            if !position.is_active || position.deposited_amount == 0 {
                return 0;
            }
            // leverage = total_collateral / deposited_amount, scaled by 100
            (position.total_collateral * 100) / position.deposited_amount
        }

        fn set_max_loops(ref self: ContractState, max: u8) {
            self.ownable.assert_only_owner();
            self.max_loops.write(max);
            self.emit(MaxLoopsUpdated { new_max: max });
        }

        fn set_min_health_factor(ref self: ContractState, factor: u256) {
            self.ownable.assert_only_owner();
            self.min_health_factor.write(factor);
            self.emit(MinHealthFactorUpdated { new_factor: factor });
        }

        fn set_btc_price(ref self: ContractState, price: u256) {
            self.ownable.assert_only_owner();
            self.btc_price.write(price);
            self.emit(BtcPriceUpdated { new_price: price });
        }

        fn set_max_slippage_bps(ref self: ContractState, bps: u256) {
            self.ownable.assert_only_owner();
            assert(bps <= 1000, Errors::SLIPPAGE_EXCEEDED); // max 10%
            self.max_slippage_bps.write(bps);
            self.emit(SlippageUpdated { new_bps: bps });
        }

        fn refresh_btc_price(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let pyth = IPythDispatcher {
                contract_address: self.pyth_oracle.read(),
            };
            let feed_id = self.btc_usd_feed_id.read();
            let price = pyth.get_price_no_older_than(feed_id, 60);
            // Pyth price has expo (e.g., -8). Convert to USDC 6-decimal scale.
            // BTC/USD price in Pyth: price.price * 10^expo
            // We need USDC units (6 decimals), so: price * 10^(6 + expo)
            // For expo=-8: price * 10^(6-8) = price / 100
            let abs_price: u256 = price.price.mag.into();
            // expo is typically -8 for BTC/USD
            // USDC has 6 decimals, BTC has 8 decimals
            // btc_price = how many USDC (6 dec) per 1 BTC (8 dec satoshis)
            // = abs_price * 10^(6) / 10^(-expo) = abs_price * 10^(6-8) = abs_price / 100
            let btc_price = abs_price / 100;
            self.btc_price.write(btc_price);
            self.emit(BtcPriceUpdated { new_price: btc_price });
        }

        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.paused.write(true);
            self.emit(Paused {});
        }

        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.paused.write(false);
            self.emit(Unpaused {});
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_not_paused(self: @ContractState) {
            assert(!self.paused.read(), Errors::PAUSED);
        }

        fn execute_loops(ref self: ContractState, user: ContractAddress, target_loops: u8) {
            let mut i: u8 = 0;
            // On first loop, deposit the initial collateral
            let position = self.positions.entry(user).read();
            let mut collateral_to_deposit = position.total_collateral;

            while i < target_loops {
                let position = self.positions.entry(user).read();

                // Step 1: Deposit collateral to Vesu
                self.deposit_to_vesu(collateral_to_deposit);

                // Step 2: Borrow USDC (65% LTV on newly deposited collateral)
                // borrow_usdc = collateral_btc_sats * btc_price / BTC_DECIMALS * LTV / 100
                let btc_price = self.btc_price.read();
                let collateral_value_usdc = (collateral_to_deposit * btc_price) / 100_000_000;
                let borrow_amount = (collateral_value_usdc * 65) / 100;
                self.borrow_from_vesu(borrow_amount);

                // Step 3: Swap USDC → BTC via DEX
                let btc_received = self.swap_stable_to_btc(borrow_amount);

                // Step 4: Update position
                let new_position = Position {
                    deposited_amount: position.deposited_amount,
                    total_collateral: position.total_collateral + btc_received,
                    vesu_collateral: position.vesu_collateral + collateral_to_deposit,
                    total_debt: position.total_debt + borrow_amount,
                    loop_count: position.loop_count + 1,
                    is_active: true,
                };
                self.positions.entry(user).write(new_position);

                self
                    .emit(
                        LoopExecuted {
                            user,
                            loop_number: i + 1,
                            collateral_added: btc_received,
                            debt_added: borrow_amount,
                        },
                    );

                // Check health factor after this loop
                let updated_position = self.positions.entry(user).read();
                let hf = self.calculate_health_factor(updated_position);
                let min_hf = self.min_health_factor.read();
                assert(hf >= min_hf, Errors::HEALTH_TOO_LOW);

                // Next iteration deposits the newly received BTC
                collateral_to_deposit = btc_received;
                i += 1;
            };
        }

        /// Unwind loops by selling vault-held BTC, repaying debt, withdrawing from Vesu.
        ///
        /// Per iteration:
        /// 1. Swap vault BTC (total_collateral - vesu_collateral) -> USDC
        /// 2. Repay debt
        /// 3. Withdraw from Vesu the collateral deposited for this loop (= vault_btc * 100/65)
        /// 4. Withdrawn BTC becomes vault BTC for next iteration
        fn execute_unwind(ref self: ContractState, user: ContractAddress, loops_to_unwind: u8) {
            let mut total_collateral_freed: u256 = 0;
            let mut total_debt_repaid: u256 = 0;
            let mut i: u8 = 0;

            while i < loops_to_unwind {
                let position = self.positions.entry(user).read();

                // BTC sitting in vault (not in Vesu)
                let vault_btc = position.total_collateral - position.vesu_collateral;

                // Step 1: Swap vault BTC -> USDC to repay debt
                let usdc_received = self.swap_btc_to_stable(vault_btc);

                // Step 2: Repay debt (cap at remaining debt)
                let repay_amount = if usdc_received < position.total_debt {
                    usdc_received
                } else {
                    position.total_debt
                };
                self.repay_to_vesu(repay_amount);

                // Step 3: Withdraw from Vesu the collateral deposited for this loop
                // The deposit for this loop = vault_btc * 100 / 65 (inverse of 65% LTV)
                // Cap at vesu_collateral to prevent underflow
                let vesu_withdraw_calc = (vault_btc * 100) / 65;
                let vesu_withdraw = if vesu_withdraw_calc < position.vesu_collateral {
                    vesu_withdraw_calc
                } else {
                    position.vesu_collateral
                };
                self.withdraw_from_vesu(vesu_withdraw);

                total_collateral_freed += vault_btc;
                total_debt_repaid += repay_amount;

                // Update position:
                // - total_collateral decreases by vault_btc (sold for USDC)
                // - vesu_collateral decreases by vesu_withdraw (now in vault)
                let new_position = Position {
                    deposited_amount: position.deposited_amount,
                    total_collateral: position.total_collateral - vault_btc,
                    vesu_collateral: position.vesu_collateral - vesu_withdraw,
                    total_debt: position.total_debt - repay_amount,
                    loop_count: position.loop_count - 1,
                    is_active: true,
                };
                self.positions.entry(user).write(new_position);

                i += 1;
            };

            self
                .emit(
                    Unwound {
                        user,
                        loops_unwound: loops_to_unwind,
                        collateral_withdrawn: total_collateral_freed,
                        debt_repaid: total_debt_repaid,
                    },
                );
        }

        fn deposit_to_vesu(ref self: ContractState, amount: u256) {
            let vesu = IVesuSingletonDispatcher {
                contract_address: self.vesu_singleton.read(),
            };
            let btc = IERC20Dispatcher { contract_address: self.btc_token.read() };
            let this = get_contract_address();

            // Approve Vesu to pull BTC from vault
            btc.approve(self.vesu_singleton.read(), amount);

            let params = ModifyPositionParams {
                pool_id: self.pool_id.read(),
                collateral_asset: self.btc_token.read(),
                debt_asset: self.stable_token.read(),
                user: this,
                collateral: Amount {
                    amount_type: AmountType::Delta,
                    denomination: AmountDenomination::Assets,
                    value: i257 { abs: amount, is_negative: false },
                },
                debt: Amount {
                    amount_type: AmountType::Delta,
                    denomination: AmountDenomination::Assets,
                    value: i257 { abs: 0, is_negative: false },
                },
                data: array![].span(),
            };

            vesu.modify_position(params);
        }

        fn borrow_from_vesu(ref self: ContractState, amount: u256) {
            let vesu = IVesuSingletonDispatcher {
                contract_address: self.vesu_singleton.read(),
            };
            let this = get_contract_address();

            let params = ModifyPositionParams {
                pool_id: self.pool_id.read(),
                collateral_asset: self.btc_token.read(),
                debt_asset: self.stable_token.read(),
                user: this,
                collateral: Amount {
                    amount_type: AmountType::Delta,
                    denomination: AmountDenomination::Assets,
                    value: i257 { abs: 0, is_negative: false },
                },
                debt: Amount {
                    amount_type: AmountType::Delta,
                    denomination: AmountDenomination::Assets,
                    value: i257 { abs: amount, is_negative: false },
                },
                data: array![].span(),
            };

            vesu.modify_position(params);
        }

        fn repay_to_vesu(ref self: ContractState, amount: u256) {
            let vesu = IVesuSingletonDispatcher {
                contract_address: self.vesu_singleton.read(),
            };
            let stable = IERC20Dispatcher { contract_address: self.stable_token.read() };
            let this = get_contract_address();

            // Approve Vesu to pull stables from vault
            stable.approve(self.vesu_singleton.read(), amount);

            let params = ModifyPositionParams {
                pool_id: self.pool_id.read(),
                collateral_asset: self.btc_token.read(),
                debt_asset: self.stable_token.read(),
                user: this,
                collateral: Amount {
                    amount_type: AmountType::Delta,
                    denomination: AmountDenomination::Assets,
                    value: i257 { abs: 0, is_negative: false },
                },
                debt: Amount {
                    amount_type: AmountType::Delta,
                    denomination: AmountDenomination::Assets,
                    value: i257 { abs: amount, is_negative: true },
                },
                data: array![].span(),
            };

            vesu.modify_position(params);
        }

        fn withdraw_from_vesu(ref self: ContractState, amount: u256) {
            let vesu = IVesuSingletonDispatcher {
                contract_address: self.vesu_singleton.read(),
            };
            let this = get_contract_address();

            let params = ModifyPositionParams {
                pool_id: self.pool_id.read(),
                collateral_asset: self.btc_token.read(),
                debt_asset: self.stable_token.read(),
                user: this,
                collateral: Amount {
                    amount_type: AmountType::Delta,
                    denomination: AmountDenomination::Assets,
                    value: i257 { abs: amount, is_negative: true },
                },
                debt: Amount {
                    amount_type: AmountType::Delta,
                    denomination: AmountDenomination::Assets,
                    value: i257 { abs: 0, is_negative: false },
                },
                data: array![].span(),
            };

            vesu.modify_position(params);
        }

        fn swap_stable_to_btc(ref self: ContractState, usdc_amount: u256) -> u256 {
            let router = IEkuboRouterDispatcher {
                contract_address: self.ekubo_router.read(),
            };
            let stable = IERC20Dispatcher { contract_address: self.stable_token.read() };

            // Approve router to pull stables
            stable.approve(self.ekubo_router.read(), usdc_amount);

            let route = array![
                RouteNode {
                    pool_key: PoolKey {
                        token0: self.btc_token.read(),
                        token1: self.stable_token.read(),
                        fee: 0,
                        tick_spacing: 0,
                        extension: 0.try_into().unwrap(),
                    },
                    sqrt_ratio_limit: 0,
                    skip_ahead: 0,
                },
            ];

            let token_amount = TokenAmount {
                token: self.stable_token.read(),
                amount: i129 { mag: usdc_amount.try_into().unwrap(), sign: false },
            };

            let results = router.multihop_swap(route, token_amount);
            let result = results.at(0);
            let btc_received: u256 = (*result.amount.mag).into();

            // Slippage check: expected BTC = usdc_amount / btc_price * 1e8
            let btc_price = self.btc_price.read();
            let expected_btc = (usdc_amount * 100_000_000) / btc_price;
            let max_slippage = self.max_slippage_bps.read();
            let min_btc = (expected_btc * (10000 - max_slippage)) / 10000;
            assert(btc_received >= min_btc, Errors::SLIPPAGE_EXCEEDED);

            btc_received
        }

        fn swap_btc_to_stable(ref self: ContractState, btc_amount: u256) -> u256 {
            let router = IEkuboRouterDispatcher {
                contract_address: self.ekubo_router.read(),
            };
            let btc = IERC20Dispatcher { contract_address: self.btc_token.read() };

            // Approve router to pull BTC
            btc.approve(self.ekubo_router.read(), btc_amount);

            let route = array![
                RouteNode {
                    pool_key: PoolKey {
                        token0: self.btc_token.read(),
                        token1: self.stable_token.read(),
                        fee: 0,
                        tick_spacing: 0,
                        extension: 0.try_into().unwrap(),
                    },
                    sqrt_ratio_limit: 0,
                    skip_ahead: 0,
                },
            ];

            let token_amount = TokenAmount {
                token: self.btc_token.read(),
                amount: i129 { mag: btc_amount.try_into().unwrap(), sign: false },
            };

            let results = router.multihop_swap(route, token_amount);
            let result = results.at(0);
            let stable_received: u256 = (*result.amount.mag).into();

            // Slippage check: expected USDC = btc_amount * btc_price / 1e8
            let btc_price = self.btc_price.read();
            let expected_stable = (btc_amount * btc_price) / 100_000_000;
            let max_slippage = self.max_slippage_bps.read();
            let min_stable = (expected_stable * (10000 - max_slippage)) / 10000;
            assert(stable_received >= min_stable, Errors::SLIPPAGE_EXCEEDED);

            stable_received
        }

        fn calculate_health_factor(self: @ContractState, position: Position) -> u256 {
            // Health Factor = (collateral_value_usdc * liquidation_threshold) / debt_usdc
            // Scaled by 100: HF=150 means 1.50
            // Will use Pyth oracle in Phase 5; for now uses stored price
            if position.total_debt == 0 {
                return 0xFFFFFFFF_u256;
            }
            let btc_price = self.btc_price.read();
            let collateral_value_usdc = (position.total_collateral * btc_price) / 100_000_000;
            // 75% liquidation threshold, result scaled by 100
            (collateral_value_usdc * 75) / position.total_debt
        }
    }
}
