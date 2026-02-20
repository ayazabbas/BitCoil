"use client";

import { useEffect, useRef, useState } from "react";

interface AnimatedNumberProps {
  value: string;
  duration?: number;
}

export function AnimatedNumber({ value, duration = 600 }: AnimatedNumberProps) {
  const [displayValue, setDisplayValue] = useState(value);
  const prevValue = useRef(value);

  useEffect(() => {
    if (prevValue.current === value) return;

    const start = parseFloat(prevValue.current) || 0;
    const end = parseFloat(value) || 0;
    const startTime = performance.now();

    if (start === end) {
      setDisplayValue(value);
      prevValue.current = value;
      return;
    }

    // Get the decimal places from the target value
    const decimalPlaces = value.includes(".") ? value.split(".")[1].length : 0;

    function animate(currentTime: number) {
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / duration, 1);

      // Ease out cubic
      const eased = 1 - Math.pow(1 - progress, 3);
      const current = start + (end - start) * eased;

      setDisplayValue(current.toFixed(decimalPlaces));

      if (progress < 1) {
        requestAnimationFrame(animate);
      } else {
        setDisplayValue(value);
      }
    }

    requestAnimationFrame(animate);
    prevValue.current = value;
  }, [value, duration]);

  return <span className="animate-count tabular-nums">{displayValue}</span>;
}
