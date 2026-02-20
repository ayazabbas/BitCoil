"use client";

import Link from "next/link";
import { useAccount, useConnect, useDisconnect } from "@starknet-react/core";
import { Button } from "@/components/ui/button";
import { shortenAddress } from "@/lib/format";
import { Wallet, LogOut, Zap } from "lucide-react";

export function Header() {
  const { address, isConnected } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();

  return (
    <header className="fixed top-0 left-0 right-0 z-40 border-b border-white/[0.06] bg-background/80 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2 group">
          <div className="relative flex h-8 w-8 items-center justify-center rounded-lg bg-[#F7931A]/10 border border-[#F7931A]/20 group-hover:bg-[#F7931A]/20 transition-colors">
            <Zap className="h-4 w-4 text-[#F7931A]" />
          </div>
          <span className="text-lg font-bold tracking-tight">
            Bit<span className="text-[#F7931A]">Coil</span>
          </span>
        </Link>

        {/* Nav */}
        <nav className="hidden items-center gap-8 md:flex">
          <a
            href="#how-it-works"
            className="text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            How It Works
          </a>
          <a
            href="#dashboard"
            className="text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            Dashboard
          </a>
          <a
            href="https://sepolia.starkscan.co/contract/0x01cb757dbf5e32fb7c2ee34b4bd1419ba9ffd350fcb857816b538cfbd25d09df"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            Contract
          </a>
        </nav>

        {/* Wallet */}
        <div className="flex items-center gap-3">
          {isConnected ? (
            <div className="flex items-center gap-2">
              <div className="hidden sm:flex items-center gap-2 rounded-lg border border-[#F7931A]/20 bg-[#F7931A]/5 px-3 py-1.5">
                <div className="h-2 w-2 rounded-full bg-emerald-400 animate-pulse" />
                <span className="font-mono text-xs text-muted-foreground">
                  {shortenAddress(address || "")}
                </span>
              </div>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => disconnect()}
                className="text-muted-foreground hover:text-foreground"
              >
                <LogOut className="h-4 w-4" />
              </Button>
            </div>
          ) : (
            <div className="flex gap-2">
              {connectors.slice(0, 1).map((connector) => (
                <Button
                  key={connector.id}
                  onClick={() => connect({ connector })}
                  size="sm"
                  className="bg-[#F7931A] text-black font-semibold hover:bg-[#FFB84D] transition-all hover:shadow-[0_0_20px_rgba(247,147,26,0.3)]"
                >
                  <Wallet className="mr-2 h-4 w-4" />
                  <span className="hidden sm:inline">{connector.name}</span>
                  <span className="sm:hidden">Connect</span>
                </Button>
              ))}
              {connectors.slice(1).map((connector) => (
                <Button
                  key={connector.id}
                  onClick={() => connect({ connector })}
                  size="sm"
                  variant="outline"
                  className="hidden sm:flex border-white/10 hover:border-[#F7931A]/30"
                >
                  {connector.name}
                </Button>
              ))}
            </div>
          )}
        </div>
      </div>
    </header>
  );
}
