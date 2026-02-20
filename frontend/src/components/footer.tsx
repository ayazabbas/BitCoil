import { Zap } from "lucide-react";
import { Separator } from "@/components/ui/separator";

export function Footer() {
  return (
    <footer className="relative border-t border-white/[0.06]">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12">
        <div className="flex flex-col items-center gap-8 sm:flex-row sm:justify-between">
          {/* Logo */}
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-md bg-[#F7931A]/10 border border-[#F7931A]/20">
              <Zap className="h-3.5 w-3.5 text-[#F7931A]" />
            </div>
            <span className="font-bold tracking-tight">
              Bit<span className="text-[#F7931A]">Coil</span>
            </span>
          </div>

          {/* Links */}
          <div className="flex items-center gap-6 text-sm text-muted-foreground">
            <a
              href="https://github.com/ayazabbas/BitCoil"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-foreground transition-colors"
            >
              GitHub
            </a>
            <a
              href="https://sepolia.starkscan.co/contract/0x01cb757dbf5e32fb7c2ee34b4bd1419ba9ffd350fcb857816b538cfbd25d09df"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-foreground transition-colors"
            >
              Contract
            </a>
            <a
              href="https://docs.starknet.io"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-foreground transition-colors"
            >
              Starknet Docs
            </a>
          </div>
        </div>

        <Separator className="my-8 bg-white/[0.04]" />

        <div className="flex flex-col items-center gap-2 sm:flex-row sm:justify-between">
          <p className="text-xs text-muted-foreground">
            Built for Starknet Re&#123;define&#125; Hackathon &mdash; Bitcoin Track
          </p>
          <p className="text-xs text-muted-foreground">
            Testnet only. Not financial advice.
          </p>
        </div>
      </div>
    </footer>
  );
}
