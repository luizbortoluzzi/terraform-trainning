import { createNavigation } from "next-intl/navigation";
import { routing } from "./routing";

// Locale-aware navigation helpers. `usePathname`/`useRouter` here strip and
// re-add the locale prefix automatically, which the language switcher relies on.
export const { Link, redirect, usePathname, useRouter, getPathname } =
  createNavigation(routing);
