"use client";

import { useAccount, useConnect } from "@starknet-react/core";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ArrowDown, Wallet, Zap, TrendingUp, Shield } from "lucide-react";

function BtcOrb() {
  return (
    <div className="relative h-64 w-64 sm:h-80 sm:w-80 flex-shrink-0">
      {/* Outer glow ring */}
      <div className="absolute inset-0 rounded-full bg-[#F7931A]/5 animate-pulse" />

      {/* Rotating orbit ring */}
      <div className="absolute inset-4 rounded-full border border-[#F7931A]/10 animate-spin-slow" />
      <div className="absolute inset-8 rounded-full border border-dashed border-[#F7931A]/15 animate-spin-slow" style={{ animationDirection: "reverse", animationDuration: "30s" }} />

      {/* Small orbiting dots */}
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="animate-orbit">
          <div className="h-2 w-2 rounded-full bg-[#F7931A]/60" />
        </div>
      </div>
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="animate-orbit" style={{ animationDelay: "-2.5s", animationDuration: "6s" }}>
          <div className="h-1.5 w-1.5 rounded-full bg-[#F7931A]/40" />
        </div>
      </div>
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="animate-orbit" style={{ animationDelay: "-5s", animationDuration: "10s" }}>
          <div className="h-1 w-1 rounded-full bg-[#FFB84D]/50" />
        </div>
      </div>

      {/* Core BTC symbol */}
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="relative flex h-28 w-28 sm:h-36 sm:w-36 items-center justify-center rounded-full border border-[#F7931A]/30 bg-gradient-to-br from-[#F7931A]/10 via-transparent to-[#F7931A]/5 glow-btc-strong">
          <span className="text-5xl sm:text-6xl font-bold text-[#F7931A] select-none" style={{ fontFamily: "var(--font-jetbrains-mono)" }}>
            &#8383;
          </span>
        </div>
      </div>
    </div>
  );
}

export function Hero() {
  const { isConnected } = useAccount();
  const { connect, connectors } = useConnect();

  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden grid-bg">
      {/* Gradient backdrop */}
      <div className="absolute inset-0 bg-gradient-to-b from-[#F7931A]/[0.02] via-transparent to-transparent" />
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 h-[500px] w-[500px] rounded-full bg-[#F7931A]/[0.03] blur-[120px]" />

      <div className="relative z-10 mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 pt-24 pb-16">
        <div className="flex flex-col items-center gap-12 lg:flex-row lg:items-center lg:justify-between lg:gap-16">
          {/* Text content */}
          <div className="flex flex-col items-center text-center lg:items-start lg:text-left lg:max-w-xl">
            <Badge
              variant="outline"
              className="mb-6 border-[#F7931A]/30 bg-[#F7931A]/5 text-[#F7931A] px-3 py-1 animate-fade-in-up"
            >
              <Zap className="mr-1.5 h-3 w-3" />
              Live on Starknet Sepolia
            </Badge>

            <h1
              className="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight leading-[1.1] animate-fade-in-up"
              style={{ animationDelay: "0.1s" }}
            >
              Leverage your{" "}
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#F7931A] to-[#FFB84D]">
                Bitcoin
              </span>{" "}
              in one click
            </h1>

            <p
              className="mt-6 text-lg text-muted-foreground max-w-lg leading-relaxed animate-fade-in-up"
              style={{ animationDelay: "0.2s" }}
            >
              BitCoil automates BTC leverage looping on Starknet. Deposit WBTC,
              choose your leverage, and the vault handles the rest &mdash;
              lending, borrowing, swapping, and re-depositing in a single
              transaction.
            </p>

            {/* Stats row */}
            <div
              className="mt-8 flex flex-wrap items-center gap-6 animate-fade-in-up"
              style={{ animationDelay: "0.3s" }}
            >
              <div className="flex items-center gap-2">
                <TrendingUp className="h-4 w-4 text-[#F7931A]" />
                <span className="text-sm text-muted-foreground">Up to <span className="text-foreground font-semibold">4x</span> leverage</span>
              </div>
              <div className="h-4 w-px bg-white/10" />
              <div className="flex items-center gap-2">
                <Shield className="h-4 w-4 text-emerald-400" />
                <span className="text-sm text-muted-foreground">On-chain <span className="text-foreground font-semibold">health monitoring</span></span>
              </div>
            </div>

            {/* CTA */}
            <div
              className="mt-10 flex flex-col sm:flex-row gap-4 animate-fade-in-up"
              style={{ animationDelay: "0.4s" }}
            >
              {isConnected ? (
                <Button
                  size="lg"
                  asChild
                  className="bg-[#F7931A] text-black font-semibold hover:bg-[#FFB84D] transition-all hover:shadow-[0_0_30px_rgba(247,147,26,0.3)] px-8"
                >
                  <a href="#dashboard">
                    Go to Dashboard
                    <ArrowDown className="ml-2 h-4 w-4" />
                  </a>
                </Button>
              ) : connectors.length > 0 ? (
                <Button
                  size="lg"
                  onClick={() => connect({ connector: connectors[0] })}
                  className="bg-[#F7931A] text-black font-semibold hover:bg-[#FFB84D] transition-all hover:shadow-[0_0_30px_rgba(247,147,26,0.3)] px-8"
                >
                  <Wallet className="mr-2 h-5 w-5" />
                  Connect Wallet
                </Button>
              ) : (
                <Button
                  size="lg"
                  asChild
                  className="bg-[#F7931A] text-black font-semibold hover:bg-[#FFB84D] transition-all hover:shadow-[0_0_30px_rgba(247,147,26,0.3)] px-8"
                >
                  <a href="#dashboard">
                    Get Started
                    <ArrowDown className="ml-2 h-4 w-4" />
                  </a>
                </Button>
              )}
              <Button
                size="lg"
                variant="outline"
                asChild
                className="border-white/10 hover:border-[#F7931A]/30 hover:bg-[#F7931A]/5"
              >
                <a href="#how-it-works">Learn More</a>
              </Button>
            </div>
          </div>

          {/* BTC Orb */}
          <div className="animate-fade-in-up" style={{ animationDelay: "0.3s" }}>
            <BtcOrb />
          </div>
        </div>
      </div>
    </section>
  );
}
