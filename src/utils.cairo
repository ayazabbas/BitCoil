// Math utilities for leverage calculations

// Calculate leverage given total collateral and initial deposit
// Returns leverage scaled by 100 (e.g., 165 = 1.65x)
pub fn calculate_leverage(total_collateral: u256, deposited_amount: u256) -> u256 {
    if deposited_amount == 0 {
        return 0;
    }
    (total_collateral * 100) / deposited_amount
}

// Calculate theoretical total exposure after N loops at a given LTV
// Formula: deposit * (1 - LTV^(loops+1)) / (1 - LTV)
// Since we can't do float math, we iterate instead
// ltv_bps: LTV in basis points (e.g., 6500 = 65%)
pub fn calculate_theoretical_exposure(
    deposit: u256, loops: u8, ltv_bps: u256,
) -> u256 {
    let mut total: u256 = deposit;
    let mut current = deposit;
    let mut i: u8 = 0;
    while i < loops {
        current = (current * ltv_bps) / 10000;
        total += current;
        i += 1;
    };
    total
}

// Calculate health factor
// collateral_value and debt should be in the same denomination (e.g., USDC)
// liquidation_threshold_bps: in basis points (e.g., 7500 = 75%)
// Returns HF scaled by 100 (150 = 1.50)
pub fn calculate_health_factor(
    collateral_value: u256, debt: u256, liquidation_threshold_bps: u256,
) -> u256 {
    if debt == 0 {
        return 0xFFFFFFFF_u256;
    }
    (collateral_value * liquidation_threshold_bps) / (debt * 100)
}
