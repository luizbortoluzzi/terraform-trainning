import { defineRouting } from "next-intl/routing";

// Central definition of the locales the site supports.
export const routing = defineRouting({
  // The two languages the site is available in.
  locales: ["en", "pt"],
  // Locale used as a fallback (and for the root redirect).
  defaultLocale: "en",
});
