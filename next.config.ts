import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Produces a minimal self-contained server in .next/standalone,
  // ideal for a small Docker image (no need to ship node_modules).
  output: "standalone",
};

export default nextConfig;
