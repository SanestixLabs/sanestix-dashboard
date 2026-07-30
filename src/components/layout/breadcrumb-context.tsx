"use client";

import { createContext, useCallback, useContext, useEffect, useState } from "react";

type BreadcrumbContextValue = {
  override: string[] | null;
  setOverride: (crumbs: string[] | null) => void;
};

const BreadcrumbContext = createContext<BreadcrumbContextValue | null>(null);

export function BreadcrumbProvider({ children }: { children: React.ReactNode }) {
  const [override, setOverrideState] = useState<string[] | null>(null);
  const setOverride = useCallback((crumbs: string[] | null) => setOverrideState(crumbs), []);

  return (
    <BreadcrumbContext.Provider value={{ override, setOverride }}>
      {children}
    </BreadcrumbContext.Provider>
  );
}

export function useBreadcrumbContext() {
  const ctx = useContext(BreadcrumbContext);
  if (!ctx) {
    throw new Error("useBreadcrumbContext must be used within a BreadcrumbProvider");
  }
  return ctx;
}

/**
 * Drop this into a page whose breadcrumb tail depends on data fetched at
 * request time (a project name, a lead title) that the static path→label
 * map in Topbar can't know in advance. Renders nothing; it just registers
 * the crumb for the Topbar to render, and clears it on unmount so the next
 * page picked via client-side navigation doesn't inherit a stale trail.
 */
export function SetBreadcrumb({ crumbs }: { crumbs: string[] }) {
  const { setOverride } = useBreadcrumbContext();
  const key = crumbs.join("\u241F");

  useEffect(() => {
    setOverride(crumbs);
    return () => setOverride(null);
    // Re-run only when the actual crumb text changes, not on every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  return null;
}
