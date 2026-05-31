const stack = [
  { label: "Next.js", detail: "Site estático (output: export)" },
  { label: "TypeScript", detail: "Tipagem ponta a ponta" },
  { label: "Terraform", detail: "Infraestrutura como código" },
  { label: "AWS S3", detail: "Bucket privado de origem" },
  { label: "AWS CloudFront", detail: "CDN global + HTTPS" },
  { label: "GitHub Actions", detail: "CI/CD com OIDC (sem chave fixa)" },
];

const flow = [
  "git push na branch main",
  "GitHub Actions builda o Next.js (export estático)",
  "Autentica na AWS via OIDC (credenciais temporárias)",
  "Sincroniza os arquivos no bucket S3",
  "Invalida o cache do CloudFront",
  "Site no ar em segundos 🚀",
];

export default function Home() {
  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-16 px-6 py-20">
      <section className="flex flex-col gap-5">
        <span className="w-fit rounded-full border border-black/10 px-3 py-1 text-xs font-medium uppercase tracking-wide text-foreground/60 dark:border-white/15">
          Portfólio · Infra na AWS
        </span>
        <h1 className="text-4xl font-bold tracking-tight sm:text-5xl">
          Olá, eu sou o Luiz 👋
        </h1>
        <p className="text-lg leading-relaxed text-foreground/70">
          Esta página simples é só a ponta do iceberg. O que importa está nos
          bastidores: ela é um site estático em Next.js, provisionado na AWS
          inteiramente com <strong>Terraform</strong> e publicado por um
          pipeline de <strong>CI/CD no GitHub Actions</strong> — tudo dentro do
          free tier.
        </p>
      </section>

      <section className="flex flex-col gap-5">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-foreground/50">
          Stack
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
          Como o deploy acontece
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
          Código-fonte no GitHub →
        </a>
      </footer>
    </main>
  );
}
