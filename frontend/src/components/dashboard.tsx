"use client";

import { useAccount } from "@starknet-react/core";
import { PositionCard } from "./dashboard/position-card";
import { DepositForm } from "./dashboard/deposit-form";
import { HealthGauge } from "./dashboard/health-gauge";
import { UnwindControls } from "./dashboard/unwind-controls";
import { Wallet } from "lucide-react";

export function Dashboard() {
  const { isConnected } = useAccount();

  return (
    <section id="dashboard" className="relative py-24 sm:py-32">
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-[#F7931A]/[0.008] to-transparent" />

      <div className="relative z-10 mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Section header */}
        <div className="text-center mb-12">
          <p className="text-sm font-semibold uppercase tracking-widest text-[#F7931A] mb-3">
            Dashboard
          </p>
          <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">
            Manage your position
          </h2>
        </div>

        {!isConnected ? (
          <div className="flex flex-col items-center justify-center py-20 border border-dashed border-white/[0.08] rounded-2xl bg-card/30">
            <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-[#F7931A]/5 border border-[#F7931A]/20 mb-6">
              <Wallet className="h-8 w-8 text-[#F7931A]/50" />
            </div>
            <p className="text-muted-foreground text-lg mb-2">
              Connect your wallet to get started
            </p>
            <p className="text-sm text-muted-foreground/60">
              Use Argent X or Braavos on Starknet Sepolia
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
            {/* Left column: Position + Health */}
            <div className="lg:col-span-5 flex flex-col gap-6">
              <PositionCard />
              <HealthGauge />
            </div>

            {/* Right column: Deposit + Unwind */}
            <div className="lg:col-span-7 flex flex-col gap-6">
              <DepositForm />
              <UnwindControls />
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
