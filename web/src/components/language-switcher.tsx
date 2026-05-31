"use client";

import { useLocale, useTranslations } from "next-intl";
import { Link, usePathname } from "@/i18n/navigation";
import { routing } from "@/i18n/routing";

// Renders one link per locale, keeping the user on the same path while swapping
// the language prefix (e.g. /en -> /pt). The active locale is highlighted.
export function LanguageSwitcher() {
  const activeLocale = useLocale();
  const pathname = usePathname();
  const t = useTranslations("languageSwitcher");

  return (
    <nav
      aria-label={t("label")}
      className="flex items-center gap-1 text-sm font-medium"
    >
      {routing.locales.map((locale) => {
        const isActive = locale === activeLocale;
        return (
          <Link
            key={locale}
            href={pathname}
            locale={locale}
            aria-current={isActive ? "true" : undefined}
            className={
              isActive
                ? "rounded-md bg-foreground px-2 py-1 text-background"
                : "rounded-md px-2 py-1 text-foreground/60 hover:text-foreground"
            }
          >
            {t(locale)}
          </Link>
        );
      })}
    </nav>
  );
}
