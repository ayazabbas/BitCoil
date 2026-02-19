#[starknet::contract]
pub mod MockDEX {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use bitcoil::interfaces::i_erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use bitcoil::interfaces::i_ekubo::{RouteNode, TokenAmount, i129};

    #[storage]
    struct Storage {
        // Mock price: how many token1 per token0 (scaled by 1e8)
        // e.g., BTC/USDC price = 100_000 * 1e6 (in USDC decimals)
        btc_token: ContractAddress,
        stable_token: ContractAddress,
        // Price of BTC in stable terms (1 BTC = price stable tokens)
        btc_price: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        btc_token: ContractAddress,
        stable_token: ContractAddress,
        btc_price: u256,
    ) {
        self.btc_token.write(btc_token);
        self.stable_token.write(stable_token);
        self.btc_price.write(btc_price);
    }

    #[abi(embed_v0)]
    impl MockEkuboImpl of bitcoil::interfaces::i_ekubo::IEkuboRouter<ContractState> {
        fn multihop_swap(
            ref self: ContractState, route: Array<RouteNode>, token_amount: TokenAmount,
        ) -> Array<TokenAmount> {
            let btc = self.btc_token.read();
            let stable = self.stable_token.read();
            let price = self.btc_price.read();
            let caller = get_caller_address();
            let this = get_contract_address();

            let input_token = token_amount.token;
            let input_amount: u256 = token_amount.amount.mag.into();

            let btc_disp = IERC20Dispatcher { contract_address: btc };
            let stable_disp = IERC20Dispatcher { contract_address: stable };

            let mut results = array![];

            if input_token == stable {
                // Swapping stable → BTC
                // BTC amount = stable_amount * 1e8 / price
                // e.g., 65000 * 1e6 USDC * 1e8 / (100000 * 1e6) = 0.65 * 1e8 BTC
                let btc_out = (input_amount * 100_000_000) / price;

                // Pull stables from caller
                stable_disp.transfer_from(caller, this, input_amount);
                // Send BTC to caller
                btc_disp.transfer(caller, btc_out);

                results
                    .append(
                        TokenAmount {
                            token: btc,
                            amount: i129 { mag: btc_out.try_into().unwrap(), sign: false },
                        },
                    );
            } else {
                // Swapping BTC → stable
                // stable_amount = btc_amount * price / 1e8
                let stable_out = (input_amount * price) / 100_000_000;

                // Pull BTC from caller
                btc_disp.transfer_from(caller, this, input_amount);
                // Send stables to caller
                stable_disp.transfer(caller, stable_out);

                results
                    .append(
                        TokenAmount {
                            token: stable,
                            amount: i129 { mag: stable_out.try_into().unwrap(), sign: false },
                        },
                    );
            }

            results
        }
    }

    // Set price for testing
    #[external(v0)]
    fn set_price(ref self: ContractState, new_price: u256) {
        self.btc_price.write(new_price);
    }
}
