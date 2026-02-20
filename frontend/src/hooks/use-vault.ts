"use client";

import { useAccount, useReadContract, useSendTransaction } from "@starknet-react/core";
import { CONTRACTS, VAULT_ABI, ERC20_ABI } from "@/lib/contracts";
import { useMemo, useCallback } from "react";

export interface Position {
  depositedAmount: bigint;
  totalCollateral: bigint;
  totalDebt: bigint;
  loopCount: number;
}

export function usePosition() {
  const { address } = useAccount();

  const { data, isLoading, error, refetch } = useReadContract({
    abi: VAULT_ABI,
    address: CONTRACTS.VAULT,
    functionName: "get_position",
    args: address ? [address] : undefined,
    enabled: !!address,
    refetchInterval: 15000,
  });

  const position = useMemo((): Position | null => {
    if (!data || !Array.isArray(data)) return null;
    return {
      depositedAmount: BigInt(String(data[0] ?? 0)),
      totalCollateral: BigInt(String(data[1] ?? 0)),
      totalDebt: BigInt(String(data[2] ?? 0)),
      loopCount: Number(data[3] ?? 0),
    };
  }, [data]);

  return { position, isLoading, error, refetch };
}

export function useHealthFactor() {
  const { address } = useAccount();

  const { data, isLoading, error } = useReadContract({
    abi: VAULT_ABI,
    address: CONTRACTS.VAULT,
    functionName: "get_health_factor",
    args: address ? [address] : undefined,
    enabled: !!address,
    refetchInterval: 15000,
  });

  const healthFactor = useMemo(() => {
    if (!data) return null;
    return BigInt(String(data));
  }, [data]);

  return { healthFactor, isLoading, error };
}

export function useEffectiveLeverage() {
  const { address } = useAccount();

  const { data, isLoading, error } = useReadContract({
    abi: VAULT_ABI,
    address: CONTRACTS.VAULT,
    functionName: "get_effective_leverage",
    args: address ? [address] : undefined,
    enabled: !!address,
    refetchInterval: 15000,
  });

  const leverage = useMemo(() => {
    if (!data) return null;
    return BigInt(String(data));
  }, [data]);

  return { leverage, isLoading, error };
}

export function useWbtcBalance() {
  const { address } = useAccount();

  const { data, isLoading, error } = useReadContract({
    abi: ERC20_ABI,
    address: CONTRACTS.WBTC,
    functionName: "balance_of",
    args: address ? [address] : undefined,
    enabled: !!address,
    refetchInterval: 15000,
  });

  const balance = useMemo(() => {
    if (!data) return null;
    return BigInt(String(data));
  }, [data]);

  return { balance, isLoading, error };
}

export function useDepositAndLoop() {
  const { sendAsync, isPending } = useSendTransaction({
    calls: [],
  });

  const depositAndLoop = useCallback(async (amount: bigint, targetLoops: number) => {
    const calls = [
      {
        contractAddress: CONTRACTS.WBTC,
        entrypoint: "approve",
        calldata: [CONTRACTS.VAULT, amount.toString(), "0"],
      },
      {
        contractAddress: CONTRACTS.VAULT,
        entrypoint: "deposit_and_loop",
        calldata: [amount.toString(), "0", targetLoops.toString()],
      },
    ];

    return sendAsync(calls);
  }, [sendAsync]);

  return { depositAndLoop, isPending };
}

export function useUnwind() {
  const { sendAsync, isPending } = useSendTransaction({
    calls: [],
  });

  const unwind = useCallback(async (loopsToUnwind: number) => {
    const calls = [
      {
        contractAddress: CONTRACTS.VAULT,
        entrypoint: "unwind",
        calldata: [loopsToUnwind.toString()],
      },
    ];

    return sendAsync(calls);
  }, [sendAsync]);

  return { unwind, isPending };
}

export function useFullUnwind() {
  const { sendAsync, isPending } = useSendTransaction({
    calls: [],
  });

  const fullUnwind = useCallback(async () => {
    const calls = [
      {
        contractAddress: CONTRACTS.VAULT,
        entrypoint: "full_unwind",
        calldata: [],
      },
    ];

    return sendAsync(calls);
  }, [sendAsync]);

  return { fullUnwind, isPending };
}
