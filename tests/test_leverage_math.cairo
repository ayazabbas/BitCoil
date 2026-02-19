use bitcoil::utils::{calculate_leverage, calculate_theoretical_exposure, calculate_health_factor};

#[test]
fn test_leverage_no_loops() {
    // 1 BTC deposited, no loops = 1x leverage
    let leverage = calculate_leverage(100_000_000, 100_000_000);
    assert(leverage == 100, 'Should be 1x (100)');
}

#[test]
fn test_leverage_with_exposure() {
    // 1.65 BTC exposure, 1 BTC deposited = 1.65x
    let leverage = calculate_leverage(165_000_000, 100_000_000);
    assert(leverage == 165, 'Should be 1.65x (165)');
}

#[test]
fn test_leverage_zero_deposit() {
    let leverage = calculate_leverage(100, 0);
    assert(leverage == 0, 'Should be 0 for zero deposit');
}

#[test]
fn test_theoretical_exposure_0_loops() {
    let exposure = calculate_theoretical_exposure(100_000_000, 0, 6500);
    assert(exposure == 100_000_000, 'Should equal deposit');
}

#[test]
fn test_theoretical_exposure_1_loop() {
    // 1 BTC at 65% LTV: 1 + 0.65 = 1.65 BTC
    let exposure = calculate_theoretical_exposure(100_000_000, 1, 6500);
    assert(exposure == 165_000_000, 'Should be 1.65 BTC');
}

#[test]
fn test_theoretical_exposure_2_loops() {
    // 1 BTC: 1 + 0.65 + 0.4225 = 2.0725 BTC
    let exposure = calculate_theoretical_exposure(100_000_000, 2, 6500);
    assert(exposure == 207_250_000, 'Should be 2.0725 BTC');
}

#[test]
fn test_theoretical_exposure_3_loops() {
    // 1 + 0.65 + 0.4225 + 0.274625 = 2.347125 BTC
    // With integer math: 100M + 65M + 42.25M + 27_462_500 = 234_712_500
    let exposure = calculate_theoretical_exposure(100_000_000, 3, 6500);
    assert(exposure == 234_712_500, 'Should be ~2.35 BTC');
}

#[test]
fn test_theoretical_exposure_4_loops() {
    let exposure = calculate_theoretical_exposure(100_000_000, 4, 6500);
    // Should be ~2.53x
    assert(exposure > 250_000_000, 'Should be > 2.5 BTC');
    assert(exposure < 260_000_000, 'Should be < 2.6 BTC');
}

#[test]
fn test_health_factor_no_debt() {
    let hf = calculate_health_factor(100_000_000, 0, 7500);
    assert(hf == 0xFFFFFFFF_u256, 'Should be max for no debt');
}

#[test]
fn test_health_factor_safe() {
    // 1.65 BTC at $100k = $165k collateral
    // $65k debt, 75% liq threshold
    // HF = (165k * 7500) / (65k * 100) = 1237500000 / 6500000 = 190.38...
    // With integers: (165_000_000_000 * 7500) / (65_000_000_000 * 100) = 190
    let hf = calculate_health_factor(165_000_000_000, 65_000_000_000, 7500);
    assert(hf == 190, 'HF should be ~190');
}

#[test]
fn test_health_factor_danger() {
    // Near liquidation: HF close to 100 (1.0)
    // collateral = $100k, debt = $75k, threshold = 75%
    // HF = (100k * 7500) / (75k * 100) = 100
    let hf = calculate_health_factor(100_000_000_000, 75_000_000_000, 7500);
    assert(hf == 100, 'HF should be 100 (at liq)');
}

#[test]
fn test_health_factor_underwater() {
    // Under water: HF < 100
    // collateral = $90k, debt = $75k, threshold = 75%
    // HF = (90k * 7500) / (75k * 100) = 90
    let hf = calculate_health_factor(90_000_000_000, 75_000_000_000, 7500);
    assert(hf == 90, 'HF should be 90 (underwater)');
}
