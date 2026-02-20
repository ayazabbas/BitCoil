"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { useHealthFactor } from "@/hooks/use-vault";
import { formatHealthFactor } from "@/lib/format";
import { Shield } from "lucide-react";
import { useMemo } from "react";

function getHealthColor(factor: number): { color: string; label: string; bgColor: string } {
  if (factor >= 2) return { color: "#22c55e", label: "Healthy", bgColor: "rgba(34, 197, 94, 0.1)" };
  if (factor >= 1.5) return { color: "#eab308", label: "Caution", bgColor: "rgba(234, 179, 8, 0.1)" };
  if (factor >= 1.2) return { color: "#f97316", label: "Warning", bgColor: "rgba(249, 115, 22, 0.1)" };
  return { color: "#ef4444", label: "Danger", bgColor: "rgba(239, 68, 68, 0.1)" };
}

export function HealthGauge() {
  const { healthFactor, isLoading } = useHealthFactor();

  const factorNum = useMemo(() => {
    if (!healthFactor) return 0;
    return Number(healthFactor) / 1e18;
  }, [healthFactor]);

  const { color, label, bgColor } = getHealthColor(factorNum);

  // Arc gauge calculation
  const percentage = Math.min(factorNum / 3, 1); // Normalize to 0-1 (3x = max)
  const strokeDasharray = `${percentage * 220} ${220 - percentage * 220}`;

  return (
    <Card className="border-white/[0.06] bg-card/50 backdrop-blur-sm overflow-hidden">
      <div className="h-px bg-gradient-to-r from-transparent via-[#F7931A]/20 to-transparent" />

      <CardHeader className="pb-2">
        <div className="flex items-center gap-2">
          <Shield className="h-4 w-4 text-muted-foreground" />
          <CardTitle className="text-base font-semibold">Health Factor</CardTitle>
        </div>
      </CardHeader>

      <CardContent className="flex flex-col items-center pb-6">
        {isLoading ? (
          <Skeleton className="h-36 w-36 rounded-full" />
        ) : (
          <div className="relative flex items-center justify-center">
            {/* SVG Arc Gauge */}
            <svg width="160" height="100" viewBox="0 0 160 100" className="overflow-visible">
              {/* Background arc */}
              <path
                d="M 15 90 A 65 65 0 0 1 145 90"
                fill="none"
                stroke="rgba(255,255,255,0.06)"
                strokeWidth="8"
                strokeLinecap="round"
              />
              {/* Value arc */}
              <path
                d="M 15 90 A 65 65 0 0 1 145 90"
                fill="none"
                stroke={color}
                strokeWidth="8"
                strokeLinecap="round"
                strokeDasharray={strokeDasharray}
                style={{
                  filter: `drop-shadow(0 0 6px ${color}40)`,
                  transition: "stroke-dasharray 1s ease-out, stroke 0.5s ease",
                }}
              />
            </svg>

            {/* Center value */}
            <div className="absolute inset-0 flex flex-col items-center justify-center pt-4">
              <span
                className="font-mono text-3xl font-bold tabular-nums"
                style={{ color }}
              >
                {factorNum > 0 ? formatHealthFactor(healthFactor ?? undefined) : "—"}
              </span>
              <span
                className="mt-1 rounded-full px-2.5 py-0.5 text-xs font-medium"
                style={{ color, backgroundColor: bgColor }}
              >
                {factorNum > 0 ? label : "No Position"}
              </span>
            </div>
          </div>
        )}

        {/* Scale labels */}
        <div className="mt-3 flex w-full max-w-[160px] justify-between text-[10px] text-muted-foreground font-mono">
          <span>0</span>
          <span>1.5</span>
          <span>3.0+</span>
        </div>
      </CardContent>
    </Card>
  );
}
