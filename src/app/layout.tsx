import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Sanestix OS | Executive Dashboard",
  description: "Internal operations dashboard — Finance, Projects & CRM at a glance.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full">
      <body className="min-h-full bg-background text-on-surface antialiased">{children}</body>
    </html>
  );
}
