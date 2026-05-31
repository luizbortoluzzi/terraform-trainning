import { getTranslations, setRequestLocale } from "next-intl/server";
import { LanguageSwitcher } from "@/components/language-switcher";

type StackItem = { label: string; detail: string };

export default async function Home({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("home");
  // Arrays come straight from the message catalog via `raw`.
  const stack = t.raw("stack") as StackItem[];
  const flow = t.raw("flow") as string[];

  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-16 px-6 py-20">
      <div className="flex items-center justify-between">
        <span className="w-fit rounded-full border border-black/10 px-3 py-1 text-xs font-medium uppercase tracking-wide text-foreground/60 dark:border-white/15">
          {t("badge")}
        </span>
        <LanguageSwitcher />
      </div>

      <section className="flex flex-col gap-5">
        <h1 className="text-4xl font-bold tracking-tight sm:text-5xl">
          {t("title")}
        </h1>
        <p className="text-lg leading-relaxed text-foreground/70">
          {t.rich("intro", {
            strong: (chunks) => <strong>{chunks}</strong>,
          })}
        </p>
      </section>

      <section className="flex flex-col gap-5">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-foreground/50">
          {t("stackHeading")}
        </h2>
        <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          {stack.map((item) => (
            <li
              key={item.label}
              className="rounded-xl border border-black/10 p-4 dark:border-white/15"
            >
              <p className="font-semibold">{item.label}</p>
              <p className="text-sm text-foreground/60">{item.detail}</p>
            </li>
          ))}
        </ul>
      </section>

      <section className="flex flex-col gap-5">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-foreground/50">
          {t("flowHeading")}
        </h2>
        <ol className="flex flex-col gap-3">
          {flow.map((step, i) => (
            <li key={step} className="flex items-start gap-3">
              <span className="mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full bg-foreground text-xs font-bold text-background">
                {i + 1}
              </span>
              <span className="text-foreground/80">{step}</span>
            </li>
          ))}
        </ol>
      </section>

      <footer className="mt-auto border-t border-black/10 pt-6 text-sm text-foreground/50 dark:border-white/15">
        <a
          className="underline underline-offset-4 hover:text-foreground"
          href="https://github.com/luizbortoluzzi/terraform-trainning"
          target="_blank"
          rel="noreferrer"
        >
          {t("sourceLink")}
        </a>
      </footer>
    </main>
  );
}
