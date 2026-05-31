import type { ReactNode } from "react";

// Next.js requires a root layout, but the real <html> document is rendered by
// `[locale]/layout.tsx` (which knows the active locale). So this just forwards
// its children. A root `not-found` also relies on this layout existing.
export default function RootLayout({ children }: { children: ReactNode }) {
  return children;
}
