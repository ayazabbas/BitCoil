#[starknet::contract]
pub mod MockLending {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map,
    };
    use bitcoil::interfaces::i_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use bitcoil::interfaces::i_vesu::{
        ModifyPositionParams, UpdatePositionResponse, LTVConfig,
        IFlashloanReceiverDispatcher, IFlashloanReceiverDispatcherTrait,
    };

    #[storage]
    struct Storage {
        // Track collateral deposits per (user, asset)
        collateral: Map<(ContractAddress, ContractAddress), u256>,
        // Track debt per (user, asset)
        debt: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl MockVesuImpl of bitcoil::interfaces::i_vesu::IVesuSingleton<ContractState> {
        fn modify_position(
            ref self: ContractState, params: ModifyPositionParams,
        ) -> UpdatePositionResponse {
            let collateral_delta = params.collateral.value;
            let debt_delta = params.debt.value;

            // Handle collateral changes
            if collateral_delta.abs > 0 {
                let current = self
                    .collateral
                    .entry((params.user, params.collateral_asset))
                    .read();
                if collateral_delta.is_negative {
                    // Withdrawing collateral - send tokens back to caller
                    self
                        .collateral
                        .entry((params.user, params.collateral_asset))
                        .write(current - collateral_delta.abs);
                    let token = IERC20Dispatcher {
                        contract_address: params.collateral_asset,
                    };
                    token.transfer(get_caller_address(), collateral_delta.abs);
                } else {
                    // Depositing collateral - pull tokens from caller
                    self
                        .collateral
                        .entry((params.user, params.collateral_asset))
                        .write(current + collateral_delta.abs);
                    let token = IERC20Dispatcher {
                        contract_address: params.collateral_asset,
                    };
                    token.transfer_from(
                        get_caller_address(), get_contract_address(), collateral_delta.abs,
                    );
                }
            }

            // Handle debt changes
            if debt_delta.abs > 0 {
                let current = self.debt.entry((params.user, params.debt_asset)).read();
                if debt_delta.is_negative {
                    // Repaying debt - pull tokens from caller
                    self
                        .debt
                        .entry((params.user, params.debt_asset))
                        .write(current - debt_delta.abs);
                    let token = IERC20Dispatcher { contract_address: params.debt_asset };
                    token.transfer_from(
                        get_caller_address(), get_contract_address(), debt_delta.abs,
                    );
                } else {
                    // Borrowing - send tokens to caller
                    self
                        .debt
                        .entry((params.user, params.debt_asset))
                        .write(current + debt_delta.abs);
                    let token = IERC20Dispatcher { contract_address: params.debt_asset };
                    token.transfer(get_caller_address(), debt_delta.abs);
                }
            }

            UpdatePositionResponse { collateral_delta, debt_delta }
        }

        fn flash_loan(
            ref self: ContractState,
            receiver: ContractAddress,
            asset: ContractAddress,
            amount: u256,
            is_legacy: bool,
            data: Span<felt252>,
        ) {
            let token = IERC20Dispatcher { contract_address: asset };

            // Send flash loan amount to receiver
            token.transfer(receiver, amount);

            // Call receiver callback
            let flash_receiver = IFlashloanReceiverDispatcher { contract_address: receiver };
            flash_receiver.on_flash_loan(get_contract_address(), asset, amount, data);

            // Verify repayment (receiver must have transferred amount back)
            let balance = token.balance_of(get_contract_address());
            assert(balance >= amount, 'Flash loan not repaid');
        }

        fn ltv_config(
            self: @ContractState,
            pool_id: felt252,
            collateral_asset: ContractAddress,
            debt_asset: ContractAddress,
        ) -> LTVConfig {
            LTVConfig { max_ltv: 65 } // 65% LTV
        }

        fn check_collateralization(
            self: @ContractState,
            pool_id: felt252,
            collateral_asset: ContractAddress,
            debt_asset: ContractAddress,
            user: ContractAddress,
        ) -> (bool, u256, u256) {
            let collateral = self.collateral.entry((user, collateral_asset)).read();
            let debt = self.debt.entry((user, debt_asset)).read();
            let is_collateralized = if debt == 0 {
                true
            } else {
                (collateral * 75) / 100 > debt
            };
            (is_collateralized, collateral, debt)
        }
    }
}
