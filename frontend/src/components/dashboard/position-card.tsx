"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { usePosition, useEffectiveLeverage } from "@/hooks/use-vault";
import { formatBtc, formatUsdc, formatLeverage } from "@/lib/format";
import { TrendingUp, Layers, Coins, Landmark } from "lucide-react";
import { AnimatedNumber } from "./animated-number";

export function PositionCard() {
  const { position, isLoading } = usePosition();
  const { leverage, isLoading: leverageLoading } = useEffectiveLeverage();

  const hasPosition = position && position.loopCount > 0;

  return (
    <Card className="border-white/[0.06] bg-card/50 backdrop-blur-sm overflow-hidden">
      {/* Top accent */}
      <div className="h-px bg-gradient-to-r from-transparent via-[#F7931A]/40 to-transparent" />

      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-base font-semibold">Position Overview</CardTitle>
          {hasPosition && (
            <Badge
              variant="outline"
              className="border-emerald-500/30 bg-emerald-500/10 text-emerald-400 text-xs"
            >
              Active
            </Badge>
          )}
          {!hasPosition && !isLoading && (
            <Badge
              variant="outline"
              className="border-white/10 bg-white/5 text-muted-foreground text-xs"
            >
              No Position
            </Badge>
          )}
        </div>
      </CardHeader>

      <CardContent className="grid grid-cols-2 gap-4">
        {/* Deposited */}
        <div className="space-y-1">
          <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <Coins className="h-3 w-3" />
            Deposited
          </div>
          {isLoading ? (
            <Skeleton className="h-7 w-24" />
          ) : (
            <div className="font-mono text-lg font-semibold">
              <AnimatedNumber value={formatBtc(position?.depositedAmount)} />
              <span className="ml-1 text-xs text-muted-foreground">BTC</span>
            </div>
          )}
        </div>

        {/* Total Collateral */}
        <div className="space-y-1">
          <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <Landmark className="h-3 w-3" />
            Collateral
          </div>
          {isLoading ? (
            <Skeleton className="h-7 w-24" />
          ) : (
            <div className="font-mono text-lg font-semibold">
              <AnimatedNumber value={formatBtc(position?.totalCollateral)} />
              <span className="ml-1 text-xs text-muted-foreground">BTC</span>
            </div>
          )}
        </div>

        {/* Total Debt */}
        <div className="space-y-1">
          <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <Layers className="h-3 w-3" />
            Debt
          </div>
          {isLoading ? (
            <Skeleton className="h-7 w-24" />
          ) : (
            <div className="font-mono text-lg font-semibold">
              <AnimatedNumber value={formatUsdc(position?.totalDebt)} />
              <span className="ml-1 text-xs text-muted-foreground">USDC</span>
            </div>
          )}
        </div>

        {/* Loops / Leverage */}
        <div className="space-y-1">
          <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <TrendingUp className="h-3 w-3" />
            Leverage
          </div>
          {isLoading || leverageLoading ? (
            <Skeleton className="h-7 w-24" />
          ) : (
            <div className="font-mono text-lg font-semibold">
              <span className="text-[#F7931A]">
                <AnimatedNumber value={leverage ? formatLeverage(leverage) : "1.00"} />x
              </span>
              <span className="ml-1.5 text-xs text-muted-foreground">
                ({position?.loopCount ?? 0} loops)
              </span>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
