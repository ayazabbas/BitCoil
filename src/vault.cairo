#[starknet::contract]
pub mod BitCoil {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use openzeppelin_access::ownable::OwnableComponent;

    use bitcoil::types::{Position, Errors, Deposited, LoopExecuted, Unwound, FullyUnwound};
    use bitcoil::interfaces::i_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use bitcoil::interfaces::i_vesu::{
        IVesuSingletonDispatcher, IVesuSingletonDispatcherTrait, ModifyPositionParams, Amount,
        AmountType, AmountDenomination, i257,
    };
    use bitcoil::interfaces::i_ekubo::{
        IEkuboRouterDispatcher, IEkuboRouterDispatcherTrait, RouteNode, PoolKey, TokenAmount, i129,
    };

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

            let loops = position.loop_count;
            if loops > 0 {
                self.execute_unwind(caller, loops);
            }

            // Withdraw remaining collateral back to user
            let position = self.positions.entry(caller).read();
            let btc = IERC20Dispatcher { contract_address: self.btc_token.read() };
            let remaining = position.total_collateral;

            if remaining > 0 {
                // Withdraw from Vesu
                self.withdraw_from_vesu(remaining);
                btc.transfer(caller, remaining);
            }

            // Clear position
            self.positions.entry(caller).write(Position {
                deposited_amount: 0,
                total_collateral: 0,
                total_debt: 0,
                loop_count: 0,
                is_active: false,
            });

            self.emit(FullyUnwound { user: caller, total_returned: remaining });
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
        }

        fn set_min_health_factor(ref self: ContractState, factor: u256) {
            self.ownable.assert_only_owner();
            self.min_health_factor.write(factor);
        }

        fn set_btc_price(ref self: ContractState, price: u256) {
            self.ownable.assert_only_owner();
            self.btc_price.write(price);
        }

        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.paused.write(true);
        }

        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.paused.write(false);
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

                // Next iteration deposits the newly received BTC
                collateral_to_deposit = btc_received;
                i += 1;
            };
        }

        fn execute_unwind(ref self: ContractState, user: ContractAddress, loops_to_unwind: u8) {
            let mut total_collateral_withdrawn: u256 = 0;
            let mut total_debt_repaid: u256 = 0;
            let mut i: u8 = 0;

            while i < loops_to_unwind {
                let position = self.positions.entry(user).read();

                // Calculate how much to unwind per loop
                let debt_per_loop = position.total_debt / position.loop_count.into();
                let collateral_per_loop = position.total_collateral
                    / (position.loop_count + 1).into();

                // Step 1: Swap BTC → USDC to repay debt
                let _usdc_received = self.swap_btc_to_stable(collateral_per_loop);

                // Step 2: Repay debt to Vesu
                self.repay_to_vesu(debt_per_loop);

                // Step 3: Withdraw collateral from Vesu
                self.withdraw_from_vesu(collateral_per_loop);

                total_collateral_withdrawn += collateral_per_loop;
                total_debt_repaid += debt_per_loop;

                let new_position = Position {
                    deposited_amount: position.deposited_amount,
                    total_collateral: position.total_collateral - collateral_per_loop,
                    total_debt: position.total_debt - debt_per_loop,
                    loop_count: position.loop_count - 1,
                    is_active: position.loop_count > 1,
                };
                self.positions.entry(user).write(new_position);

                i += 1;
            };

            self
                .emit(
                    Unwound {
                        user,
                        loops_unwound: loops_to_unwind,
                        collateral_withdrawn: total_collateral_withdrawn,
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
