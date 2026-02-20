"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { useDepositAndLoop, useWbtcBalance, usePosition } from "@/hooks/use-vault";
import { formatBtc, parseBtcAmount } from "@/lib/format";
import { Loader2, ArrowDownToLine, RefreshCcw } from "lucide-react";
import { toast } from "sonner";

export function DepositForm() {
  const [amount, setAmount] = useState("");
  const [loops, setLoops] = useState(2);
  const { balance, isLoading: balanceLoading } = useWbtcBalance();
  const { depositAndLoop, isPending } = useDepositAndLoop();
  const { refetch } = usePosition();

  const handleDeposit = async () => {
    if (!amount || parseFloat(amount) <= 0) {
      toast.error("Enter an amount to deposit");
      return;
    }

    try {
      const parsedAmount = parseBtcAmount(amount);
      await depositAndLoop(parsedAmount, loops);
      toast.success("Deposit & loop transaction submitted!");
      setAmount("");
      // Refetch position data
      setTimeout(() => refetch(), 5000);
    } catch (err) {
      toast.error("Transaction failed", {
        description: err instanceof Error ? err.message : "Unknown error",
      });
    }
  };

  const handleMaxClick = () => {
    if (balance) {
      setAmount(formatBtc(balance));
    }
  };

  const estimatedLeverage = (1 + loops * 0.65).toFixed(2);

  return (
    <Card className="border-white/[0.06] bg-card/50 backdrop-blur-sm overflow-hidden">
      <div className="h-px bg-gradient-to-r from-transparent via-[#F7931A]/40 to-transparent" />

      <CardHeader className="pb-4">
        <div className="flex items-center gap-2">
          <ArrowDownToLine className="h-4 w-4 text-[#F7931A]" />
          <CardTitle className="text-base font-semibold">Deposit & Loop</CardTitle>
        </div>
      </CardHeader>

      <CardContent className="space-y-6">
        {/* Amount input */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-sm">
            <span className="text-muted-foreground">Amount</span>
            <div className="flex items-center gap-2">
              <span className="text-xs text-muted-foreground">Balance:</span>
              {balanceLoading ? (
                <Skeleton className="h-4 w-16" />
              ) : (
                <button
                  onClick={handleMaxClick}
                  className="font-mono text-xs text-[#F7931A] hover:text-[#FFB84D] transition-colors"
                >
                  {formatBtc(balance)} WBTC
                </button>
              )}
            </div>
          </div>

          <div className="relative flex items-center rounded-xl border border-white/[0.08] bg-white/[0.03] focus-within:border-[#F7931A]/30 focus-within:glow-btc transition-all">
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              step="0.0001"
              min="0"
              className="w-full bg-transparent px-4 py-3 font-mono text-lg outline-none placeholder:text-muted-foreground/40 [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
            />
            <div className="flex items-center gap-2 pr-4">
              <Button
                variant="ghost"
                size="sm"
                onClick={handleMaxClick}
                className="h-7 px-2 text-xs text-muted-foreground hover:text-[#F7931A]"
              >
                MAX
              </Button>
              <Badge variant="outline" className="border-[#F7931A]/20 bg-[#F7931A]/5 text-[#F7931A] pointer-events-none">
                WBTC
              </Badge>
            </div>
          </div>
        </div>

        {/* Loop slider */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <RefreshCcw className="h-3.5 w-3.5 text-muted-foreground" />
              <span className="text-sm text-muted-foreground">Loops</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="font-mono text-2xl font-bold text-[#F7931A]">{loops}</span>
              <span className="text-sm text-muted-foreground">
                ≈ {estimatedLeverage}x
              </span>
            </div>
          </div>

          <Slider
            value={[loops]}
            onValueChange={(v) => setLoops(v[0])}
            min={1}
            max={4}
            step={1}
            className="[&_[role=slider]]:bg-[#F7931A] [&_[role=slider]]:border-[#F7931A] [&_[role=slider]]:shadow-[0_0_10px_rgba(247,147,26,0.3)] [&_.relative>div]:bg-[#F7931A]"
          />

          <div className="flex justify-between text-xs text-muted-foreground font-mono">
            <span>1 loop</span>
            <span>2 loops</span>
            <span>3 loops</span>
            <span>4 loops</span>
          </div>
        </div>

        {/* Info box */}
        <div className="rounded-lg border border-white/[0.06] bg-white/[0.02] p-3 space-y-2">
          <div className="flex justify-between text-xs">
            <span className="text-muted-foreground">Estimated leverage</span>
            <span className="font-mono text-foreground">{estimatedLeverage}x</span>
          </div>
          <div className="flex justify-between text-xs">
            <span className="text-muted-foreground">Loops</span>
            <span className="font-mono text-foreground">{loops}</span>
          </div>
          <div className="flex justify-between text-xs">
            <span className="text-muted-foreground">Protocol</span>
            <span className="font-mono text-foreground">Vesu + Ekubo</span>
          </div>
        </div>

        {/* Submit */}
        <Button
          onClick={handleDeposit}
          disabled={isPending || !amount || parseFloat(amount) <= 0}
          className="w-full bg-[#F7931A] text-black font-semibold hover:bg-[#FFB84D] disabled:opacity-40 disabled:cursor-not-allowed transition-all hover:shadow-[0_0_30px_rgba(247,147,26,0.2)] h-12 text-base"
        >
          {isPending ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Submitting...
            </>
          ) : (
            <>
              <ArrowDownToLine className="mr-2 h-4 w-4" />
              Deposit & Loop
            </>
          )}
        </Button>
      </CardContent>
    </Card>
  );
}
