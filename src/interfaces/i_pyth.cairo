#[derive(Copy, Drop, Serde)]
pub struct Price {
    pub price: i64,
    pub conf: u64,
    pub expo: i32,
    pub publish_time: u64,
}

#[derive(Copy, Drop, Serde)]
pub struct i64 {
    pub mag: u64,
    pub sign: bool,
}

#[derive(Copy, Drop, Serde)]
pub struct i32 {
    pub mag: u32,
    pub sign: bool,
}

#[starknet::interface]
pub trait IPyth<TContractState> {
    fn get_price_no_older_than(
        self: @TContractState, price_feed_id: u256, max_age: u64,
    ) -> Price;
}
