"use client";

import { Card, CardContent } from "@/components/ui/card";
import { ArrowRight, Download, RefreshCcw, TrendingUp } from "lucide-react";

const steps = [
  {
    number: "01",
    title: "Deposit WBTC",
    description:
      "Connect your Starknet wallet and deposit wrapped BTC into the BitCoil vault. Your BTC stays on-chain, secured by Starknet's ZK proofs.",
    icon: Download,
    accent: "#F7931A",
  },
  {
    number: "02",
    title: "Choose Leverage",
    description:
      "Select 1-4 loops of leverage. Each loop deposits BTC as collateral, borrows stablecoins, swaps back to BTC, and re-deposits — all automated.",
    icon: RefreshCcw,
    accent: "#FFB84D",
  },
  {
    number: "03",
    title: "Earn Amplified Returns",
    description:
      "Your leveraged BTC position amplifies upside exposure. Monitor health factor in real-time. Unwind partially or fully at any time.",
    icon: TrendingUp,
    accent: "#F7931A",
  },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="relative py-24 sm:py-32">
      {/* Section gradient */}
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-[#F7931A]/[0.01] to-transparent" />

      <div className="relative z-10 mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Section header */}
        <div className="text-center mb-16">
          <p className="text-sm font-semibold uppercase tracking-widest text-[#F7931A] mb-3">
            How It Works
          </p>
          <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">
            Leverage in three steps
          </h2>
          <p className="mt-4 text-muted-foreground max-w-2xl mx-auto">
            No manual looping. No complex transactions. BitCoil handles the
            entire leverage strategy in a single vault interaction.
          </p>
        </div>

        {/* Steps */}
        <div className="grid grid-cols-1 gap-6 md:grid-cols-3 md:gap-4">
          {steps.map((step, index) => (
            <div key={step.number} className="relative flex">
              <Card className="group relative flex-1 border-white/[0.06] bg-card/50 backdrop-blur-sm hover:border-[#F7931A]/20 transition-all duration-300 hover:glow-btc overflow-hidden">
                {/* Top accent line */}
                <div
                  className="absolute top-0 left-0 right-0 h-px opacity-50 group-hover:opacity-100 transition-opacity"
                  style={{
                    background: `linear-gradient(90deg, transparent, ${step.accent}, transparent)`,
                  }}
                />

                <CardContent className="p-6 sm:p-8">
                  {/* Step number */}
                  <div className="flex items-center justify-between mb-6">
                    <span
                      className="font-mono text-4xl font-bold opacity-10 group-hover:opacity-20 transition-opacity"
                      style={{ color: step.accent }}
                    >
                      {step.number}
                    </span>
                    <div
                      className="flex h-10 w-10 items-center justify-center rounded-lg border border-white/[0.06] bg-white/[0.03] group-hover:border-[#F7931A]/20 group-hover:bg-[#F7931A]/5 transition-all"
                    >
                      <step.icon className="h-5 w-5 text-muted-foreground group-hover:text-[#F7931A] transition-colors" />
                    </div>
                  </div>

                  <h3 className="text-xl font-semibold mb-3">{step.title}</h3>
                  <p className="text-sm text-muted-foreground leading-relaxed">
                    {step.description}
                  </p>
                </CardContent>
              </Card>

              {/* Arrow connector (between cards on desktop) */}
              {index < steps.length - 1 && (
                <div className="hidden md:flex items-center justify-center w-4 -mr-2 z-10">
                  <ArrowRight className="h-4 w-4 text-[#F7931A]/30" />
                </div>
              )}
            </div>
          ))}
        </div>

        {/* Protocol logos */}
        <div className="mt-16 flex flex-col items-center gap-4">
          <p className="text-xs text-muted-foreground uppercase tracking-widest">
            Built on
          </p>
          <div className="flex items-center gap-8 text-muted-foreground">
            <span className="font-mono text-sm hover:text-foreground transition-colors">
              Starknet
            </span>
            <span className="text-white/10">|</span>
            <span className="font-mono text-sm hover:text-foreground transition-colors">
              Vesu V2
            </span>
            <span className="text-white/10">|</span>
            <span className="font-mono text-sm hover:text-foreground transition-colors">
              Ekubo
            </span>
            <span className="text-white/10">|</span>
            <span className="font-mono text-sm hover:text-foreground transition-colors">
              Pyth
            </span>
          </div>
        </div>
      </div>
    </section>
  );
}
