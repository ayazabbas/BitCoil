/**
 * Format a u256 value from the contract (8 decimals for WBTC) to a human-readable string.
 */
export function formatBtc(value: bigint | string | null | undefined, decimals = 8): string {
  if (!value) return "0.00";
  const raw = typeof value === "string" ? BigInt(value) : value;
  const divisor = BigInt(10 ** decimals);
  const whole = raw / divisor;
  const frac = raw % divisor;
  const fracStr = frac.toString().padStart(decimals, "0").slice(0, 6);
  return `${whole}.${fracStr}`;
}

/**
 * Format a u256 value for USDC (6 decimals).
 */
export function formatUsdc(value: bigint | string | null | undefined): string {
  return formatBtc(value, 6);
}

/**
 * Parse a human-readable BTC amount to contract u256 (8 decimals).
 */
export function parseBtcAmount(amount: string, decimals = 8): bigint {
  const parts = amount.split(".");
  const whole = BigInt(parts[0] || "0") * BigInt(10 ** decimals);
  if (parts[1]) {
    const fracStr = parts[1].padEnd(decimals, "0").slice(0, decimals);
    return whole + BigInt(fracStr);
  }
  return whole;
}

/**
 * Format health factor (stored as u256 with 18 decimals) to a readable number.
 */
export function formatHealthFactor(value: bigint | string | null | undefined): string {
  if (!value) return "0.00";
  const raw = typeof value === "string" ? BigInt(value) : value;
  const divisor = BigInt(10 ** 18);
  const whole = raw / divisor;
  const frac = (raw % divisor).toString().padStart(18, "0").slice(0, 2);
  return `${whole}.${frac}`;
}

/**
 * Format leverage (stored as u256 with 18 decimals) to Nx format.
 */
export function formatLeverage(value: bigint | string | null | undefined): string {
  if (!value) return "1.00";
  const raw = typeof value === "string" ? BigInt(value) : value;
  const divisor = BigInt(10 ** 18);
  const whole = raw / divisor;
  const frac = (raw % divisor).toString().padStart(18, "0").slice(0, 2);
  return `${whole}.${frac}`;
}

/**
 * Shorten a hex address for display.
 */
export function shortenAddress(address: string): string {
  if (!address) return "";
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}
