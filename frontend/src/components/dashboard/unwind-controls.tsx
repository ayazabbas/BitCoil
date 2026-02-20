"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { usePosition, useUnwind, useFullUnwind } from "@/hooks/use-vault";
import { Loader2, ArrowUpFromLine, AlertTriangle } from "lucide-react";
import { toast } from "sonner";

export function UnwindControls() {
  const { position, refetch } = usePosition();
  const { unwind, isPending: unwindPending } = useUnwind();
  const { fullUnwind, isPending: fullUnwindPending } = useFullUnwind();
  const [loopsToUnwind, setLoopsToUnwind] = useState(1);
  const [confirmOpen, setConfirmOpen] = useState(false);

  const hasPosition = position && position.loopCount > 0;
  const maxUnwind = position?.loopCount ?? 1;

  const handlePartialUnwind = async () => {
    try {
      await unwind(loopsToUnwind);
      toast.success(`Unwinding ${loopsToUnwind} loop${loopsToUnwind > 1 ? "s" : ""}...`);
      setTimeout(() => refetch(), 5000);
    } catch (err) {
      toast.error("Unwind failed", {
        description: err instanceof Error ? err.message : "Unknown error",
      });
    }
  };

  const handleFullUnwind = async () => {
    try {
      await fullUnwind();
      setConfirmOpen(false);
      toast.success("Full unwind submitted! Closing your entire position...");
      setTimeout(() => refetch(), 5000);
    } catch (err) {
      toast.error("Full unwind failed", {
        description: err instanceof Error ? err.message : "Unknown error",
      });
    }
  };

  return (
    <Card className="border-white/[0.06] bg-card/50 backdrop-blur-sm overflow-hidden">
      <div className="h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />

      <CardHeader className="pb-4">
        <div className="flex items-center gap-2">
          <ArrowUpFromLine className="h-4 w-4 text-muted-foreground" />
          <CardTitle className="text-base font-semibold">Unwind Position</CardTitle>
        </div>
      </CardHeader>

      <CardContent className="space-y-6">
        {!hasPosition ? (
          <div className="text-center py-8 text-muted-foreground text-sm">
            No active position to unwind
          </div>
        ) : (
          <>
            {/* Partial unwind */}
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Loops to unwind</span>
                <span className="font-mono text-lg font-bold">{loopsToUnwind}</span>
              </div>

              <Slider
                value={[loopsToUnwind]}
                onValueChange={(v) => setLoopsToUnwind(v[0])}
                min={1}
                max={maxUnwind}
                step={1}
                className="[&_[role=slider]]:bg-white [&_[role=slider]]:border-white/50 [&_.relative>div]:bg-white/70"
              />

              <div className="flex justify-between text-xs text-muted-foreground font-mono">
                <span>1</span>
                {maxUnwind > 1 && <span>{maxUnwind}</span>}
              </div>

              <Button
                onClick={handlePartialUnwind}
                disabled={unwindPending}
                variant="outline"
                className="w-full border-white/10 hover:border-white/20 hover:bg-white/5 h-10"
              >
                {unwindPending ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Unwinding...
                  </>
                ) : (
                  <>
                    <ArrowUpFromLine className="mr-2 h-4 w-4" />
                    Unwind {loopsToUnwind} Loop{loopsToUnwind > 1 ? "s" : ""}
                  </>
                )}
              </Button>
            </div>

            {/* Divider */}
            <div className="flex items-center gap-3">
              <div className="h-px flex-1 bg-white/[0.06]" />
              <span className="text-xs text-muted-foreground">or</span>
              <div className="h-px flex-1 bg-white/[0.06]" />
            </div>

            {/* Full unwind with confirmation dialog */}
            <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
              <DialogTrigger asChild>
                <Button
                  variant="outline"
                  className="w-full border-red-500/20 text-red-400 hover:bg-red-500/10 hover:border-red-500/30 h-10"
                >
                  <AlertTriangle className="mr-2 h-4 w-4" />
                  Full Unwind — Close Position
                </Button>
              </DialogTrigger>
              <DialogContent className="border-white/[0.08] bg-card">
                <DialogHeader>
                  <DialogTitle className="flex items-center gap-2">
                    <AlertTriangle className="h-5 w-5 text-red-400" />
                    Confirm Full Unwind
                  </DialogTitle>
                  <DialogDescription className="text-muted-foreground">
                    This will close your entire position — repaying all debt, withdrawing all
                    collateral, and returning your BTC. This action cannot be undone.
                  </DialogDescription>
                </DialogHeader>
                <div className="rounded-lg border border-white/[0.06] bg-white/[0.02] p-3 space-y-1 text-sm">
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Current loops</span>
                    <span className="font-mono">{position?.loopCount}</span>
                  </div>
                </div>
                <DialogFooter className="gap-2 sm:gap-0">
                  <Button
                    variant="ghost"
                    onClick={() => setConfirmOpen(false)}
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={handleFullUnwind}
                    disabled={fullUnwindPending}
                    className="bg-red-500 text-white hover:bg-red-600"
                  >
                    {fullUnwindPending ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        Unwinding...
                      </>
                    ) : (
                      "Confirm Full Unwind"
                    )}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </>
        )}
      </CardContent>
    </Card>
  );
}
