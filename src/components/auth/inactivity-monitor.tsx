"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { signOutInactive } from "@/app/auth/actions";

// After this much idle time (no mouse/keyboard/touch/scroll activity),
// the user is signed out automatically.
const INACTIVITY_LIMIT_MS = 30 * 60 * 1000; // 30 minutes
// A warning modal with a countdown appears this long before the cutoff,
// so the user gets a chance to stay signed in.
const WARNING_BEFORE_MS = 60 * 1000; // 60 seconds
// Activity events are throttled to at most once per this interval, so a
// mousemove-heavy session doesn't spam timer resets.
const THROTTLE_MS = 5000;

export function InactivityMonitor() {
  const [warning, setWarning] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(WARNING_BEFORE_MS / 1000);

  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const warningRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const countdownRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const lastActivityRef = useRef(Date.now());

  const clearAllTimers = useCallback(() => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    if (warningRef.current) clearTimeout(warningRef.current);
    if (countdownRef.current) clearInterval(countdownRef.current);
  }, []);

  const reset = useCallback(() => {
    clearAllTimers();
    setWarning(false);
    setSecondsLeft(WARNING_BEFORE_MS / 1000);

    warningRef.current = setTimeout(() => {
      setWarning(true);
      let remaining = WARNING_BEFORE_MS / 1000;
      countdownRef.current = setInterval(() => {
        remaining -= 1;
        setSecondsLeft(remaining);
        if (remaining <= 0 && countdownRef.current) {
          clearInterval(countdownRef.current);
        }
      }, 1000);
    }, INACTIVITY_LIMIT_MS - WARNING_BEFORE_MS);

    timeoutRef.current = setTimeout(() => {
      signOutInactive();
    }, INACTIVITY_LIMIT_MS);
  }, [clearAllTimers]);

  useEffect(() => {
    const events: (keyof WindowEventMap)[] = [
      "mousemove",
      "mousedown",
      "keydown",
      "touchstart",
      "scroll",
    ];

    const handleActivity = () => {
      const now = Date.now();
      if (now - lastActivityRef.current > THROTTLE_MS) {
        lastActivityRef.current = now;
        reset();
      }
    };

    events.forEach((evt) => window.addEventListener(evt, handleActivity, { passive: true }));
    reset();

    return () => {
      events.forEach((evt) => window.removeEventListener(evt, handleActivity));
      clearAllTimers();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!warning) return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 px-4">
      <div className="hairline w-full max-w-sm border bg-surface p-6 text-center">
        <p className="mb-1 font-mono-data text-[11px] uppercase tracking-wider text-primary">
          Session expiring
        </p>
        <h2 className="mb-2 text-[18px] font-bold text-on-surface">Still there?</h2>
        <p className="mb-5 text-[13px] text-on-surface-variant">
          You&apos;ve been inactive. You&apos;ll be signed out in{" "}
          <span className="font-mono-data text-on-surface">{secondsLeft}s</span>.
        </p>
        <button
          type="button"
          onClick={() => reset()}
          className="w-full bg-primary px-4 py-2.5 font-mono-data text-[11px] font-medium uppercase tracking-wider text-on-primary transition hover:brightness-110 active:scale-95"
        >
          Stay signed in
        </button>
      </div>
    </div>
  );
}
