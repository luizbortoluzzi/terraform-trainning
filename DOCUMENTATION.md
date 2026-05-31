# 📘 Documentação — Portfólio Next.js na AWS com Terraform + CI/CD

Este documento explica, **passo a passo**, como este projeto foi construído e
como colocá-lo no ar. A ideia é servir tanto de portfólio quanto de material de
estudo de **Terraform**, **AWS** e **CI/CD com GitHub Actions** — tudo dentro do
**free tier** da AWS.

---

## 1. Visão geral

Um site estático (Next.js + TypeScript) hospedado na AWS, com infraestrutura
100% descrita em Terraform e deploy automático a cada push na `main`.

### Arquitetura

```
 Você (git push main)
        │
        ▼
 ┌─────────────────────┐     OIDC (token temporário, sem chave fixa)
 │   GitHub Actions     │ ─────────────────────────────────────────┐
 │  1. build Next.js    │                                           ▼
 │  2. aws s3 sync       │                                  ┌──────────────┐
 │  3. invalidate CF     │ ────────────────────────────────▶│  AWS (conta) │
 └─────────────────────┘                                   └──────────────┘
                                                                   │
                  ┌────────────────────────────────────────────────┤
                  ▼                                                  ▼
        ┌──────────────────┐   OAC (privado)        ┌────────────────────────┐
        │  S3 (bucket do   │◀───────────────────────│  CloudFront (CDN+HTTPS) │
        │  site, PRIVADO)  │                         └────────────────────────┘
        └──────────────────┘                                       │
                                                                   ▼
                                                        usuário final acessa
                                                       https://xxxx.cloudfront.net
```

### Por que cada peça?

| Componente | Papel | Por que é grátis (free tier) |
|---|---|---|
| **S3** | Guarda os arquivos do site (bucket privado) | 5 GB grátis/12 meses; depois centavos para um site pequeno |
| **CloudFront** | CDN global + HTTPS grátis | 1 TB de transferência/mês grátis (permanente) |
| **OAC** | Deixa só o CloudFront ler o S3 | Sem custo |
| **DynamoDB** | Lock do estado do Terraform | 25 GB grátis (permanente); uso mínimo |
| **IAM + OIDC** | Deploy sem chave fixa | Sem custo |
| **GitHub Actions** | Pipeline de CI/CD | Grátis para repositórios públicos |

> 💡 Não usamos domínio próprio (Route 53 custa US$ 0,50/mês por hosted zone).
> Acessamos pela URL padrão `*.cloudfront.net`, que já vem com HTTPS grátis.

---

## 2. Estrutura do repositório

```
terraform-trainning/
├── DOCUMENTATION.md            ← este arquivo
├── README.md
├── .gitignore                  ← ignora tfstate, node_modules, segredos
├── web/                        ← aplicação Next.js + TypeScript
│   ├── src/app/page.tsx        ← a página do portfólio
│   ├── next.config.ts          ← output: "export" (gera site estático)
│   └── ...
├── terraform/
│   ├── bootstrap/              ← cria o bucket de estado + lock (roda 1x)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── infra/                  ← S3 + CloudFront + OAC + OIDC/IAM
│       ├── backend.tf          ← estado remoto no S3
│       ├── providers.tf
│       ├── variables.tf
│       ├── s3.tf
│       ├── cloudfront.tf
│       ├── github_oidc.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
└── .github/workflows/
    ├── ci.yml                  ← valida build + Terraform em PRs
    └── deploy.yml              ← publica na AWS no push da main
```

---

## 3. Pré-requisitos

| Ferramenta | Versão usada | Como verificar |
|---|---|---|
| Node.js | 20+ (aqui: v24) | `node --version` |
| Terraform | 1.6+ (aqui: v1.15.5) | `terraform version` |
| AWS CLI | v2 (aqui: v2.34) | `aws --version` |
| Conta AWS | — | acesso ao console |
| Conta GitHub | — | repositório criado |

> As ferramentas (Terraform e AWS CLI) foram instaladas em `~/.local/bin` para
> não precisar de `sudo`. Se você for refazer em outra máquina, baixe o
> Terraform de [releases.hashicorp.com](https://releases.hashicorp.com/terraform/)
> e a AWS CLI de [aws.amazon.com/cli](https://aws.amazon.com/cli/).

---

## 4. O app Next.js (a parte fácil)

O site é um Next.js criado com `create-next-app` (TypeScript + Tailwind), com
uma mudança chave em [`web/next.config.ts`](web/next.config.ts):

```ts
const nextConfig: NextConfig = {
  output: "export",          // gera HTML/CSS/JS puro na pasta out/
  images: { unoptimized: true },
  trailingSlash: true,       // /rota/ -> /rota/index.html
};
```

`output: "export"` é o que permite rodar o Next **sem servidor Node** — ele vira
um punhado de arquivos estáticos, perfeito para S3 + CloudFront.

**Rodar localmente:**

```bash
cd web
npm install
npm run dev        # http://localhost:3000  (modo desenvolvimento)
npm run build      # gera a pasta web/out/  (o que vai pro S3)
```

---

## 5. Configurar a conta AWS (uma vez)

> ⚠️ Estes passos são **manuais no console da AWS** porque envolvem criar conta
> e credenciais — coisas que não dá (nem se deve) automatizar.

### 5.1. Criar a conta AWS

1. Acesse <https://aws.amazon.com/free> e crie uma conta.
2. Será pedido um cartão de crédito (a AWS faz uma cobrança simbólica de
   verificação e estorna). Ficando no free tier, **não há cobrança**.
3. Ative um **alerta de billing** para dormir tranquilo:
   - Console → *Billing and Cost Management* → *Budgets* → criar um budget de,
     por exemplo, **US$ 1,00**, com alerta por e-mail. Assim, se algo sair do
     free tier, você é avisado na hora.

### 5.2. Criar um usuário IAM para uso local (não use a conta root!)

A conta "root" (o e-mail que criou a conta) é poderosa demais para o dia a dia.
Crie um usuário separado:

1. Console → **IAM** → *Users* → *Create user*.
2. Nome: `terraform-admin`.
3. Em permissões, anexe a policy gerenciada **AdministratorAccess**
   (é só para você rodar o Terraform da sua máquina; o deploy no CI usará uma
   role bem mais restrita).
4. Depois de criado: aba *Security credentials* → *Create access key* →
   escolha *Command Line Interface (CLI)* → copie o **Access key ID** e o
   **Secret access key**.

### 5.3. Configurar a AWS CLI na sua máquina

```bash
aws configure
# AWS Access Key ID:     <cole aqui>
# AWS Secret Access Key: <cole aqui>
# Default region name:   us-east-1
# Default output format: json
```

Teste:

```bash
aws sts get-caller-identity
# deve mostrar seu Account ID e o ARN do usuário terraform-admin
```

---

## 6. Bootstrap — criar o "cofre" do estado do Terraform

O Terraform guarda o que ele criou num arquivo de **estado** (`tfstate`).
Em projetos sérios esse arquivo fica num bucket S3 (compartilhável, versionado)
com um **lock** no DynamoDB (pra dois `apply` não rodarem juntos).

Mas há um problema do ovo e da galinha: *quem cria esse bucket?* O módulo
`bootstrap` resolve isso — ele cria o bucket + a tabela usando **estado local**.

```bash
cd terraform/bootstrap

terraform init      # baixa o provider AWS
terraform plan      # mostra o que será criado (bucket + tabela)
terraform apply     # digite "yes" para confirmar
```

Saída esperada (outputs):

```
state_bucket_name = "luizbortoluzzi-tfstate-portfolio"
lock_table_name   = "terraform-lock-portfolio"
```

> 🔴 **O nome do bucket precisa ser único no mundo todo.** Se der erro de nome
> já em uso, edite `state_bucket_name` em
> [`terraform/bootstrap/variables.tf`](terraform/bootstrap/variables.tf) **e**
> o `bucket` em [`terraform/infra/backend.tf`](terraform/infra/backend.tf) para
> o mesmo valor.

---

## 7. Infra — S3 + CloudFront + OIDC

Agora o módulo principal. Ele usa o **backend remoto** (o bucket que acabamos de
criar) — repare em [`terraform/infra/backend.tf`](terraform/infra/backend.tf).

```bash
cd ../infra      # (a partir de terraform/bootstrap)

terraform init   # conecta no backend S3; vai dizer "Successfully configured the backend s3"
terraform plan   # revise o que será criado
terraform apply  # "yes" para confirmar
```

Isso cria:

- O **bucket S3 do site** (privado);
- A **distribuição CloudFront** com HTTPS;
- O **OAC** e a **bucket policy** ligando os dois;
- O **provedor OIDC do GitHub** e a **role IAM** de deploy.

> ⏱️ O CloudFront leva ~3–5 minutos para "deployar" na primeira vez. É normal.

Anote os **outputs** (vamos usá-los no GitHub):

```
cloudfront_url             = "https://d123abc.cloudfront.net"
cloudfront_distribution_id = "E1XXXXXXXXXXXX"
site_bucket_name           = "luizbortoluzzi-portfolio-site"
github_actions_role_arn    = "arn:aws:iam::123456789012:role/portfolio-terraform-github-actions"
```

Para reexibir depois: `terraform output`.

---

## 8. Conectar o GitHub Actions à AWS (OIDC)

O workflow de deploy precisa saber 4 coisas. Elas **não são secretas** (são só
identificadores), então usamos **Repository Variables** (não secrets).

### Pela interface do GitHub

Repositório → **Settings** → *Secrets and variables* → **Actions** → aba
**Variables** → *New repository variable*. Crie as quatro:

| Nome da variável | Valor (vem dos outputs do Terraform) |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `AWS_ROLE_ARN` | o `github_actions_role_arn` |
| `AWS_S3_BUCKET` | o `site_bucket_name` |
| `AWS_CLOUDFRONT_DISTRIBUTION_ID` | o `cloudfront_distribution_id` |

### Ou pela linha de comando (gh CLI)

```bash
gh variable set AWS_REGION                     --body "us-east-1"
gh variable set AWS_ROLE_ARN                   --body "$(cd terraform/infra && terraform output -raw github_actions_role_arn)"
gh variable set AWS_S3_BUCKET                  --body "$(cd terraform/infra && terraform output -raw site_bucket_name)"
gh variable set AWS_CLOUDFRONT_DISTRIBUTION_ID --body "$(cd terraform/infra && terraform output -raw cloudfront_distribution_id)"
```

---

## 9. Primeiro deploy 🚀

Com a infra de pé e as variáveis configuradas:

```bash
git add .
git commit -m "feat: site, infra Terraform e CI/CD"
git push origin main
```

Vá em **Actions** no GitHub e acompanhe o workflow **Deploy**. Ele vai:

1. Buildar o Next.js (`web/out`);
2. Assumir a role via OIDC (sem nenhuma chave guardada);
3. `aws s3 sync` para o bucket;
4. Invalidar o cache do CloudFront.

Quando terminar, abra a `cloudfront_url`. **Site no ar!** 🎉

> ⚠️ **Ordem importa:** rode o `terraform apply` da infra e configure as
> variáveis **antes** de depender do deploy. Se você der push na main antes da
> role existir, o job de deploy falha — é só rodar de novo depois (botão
> *Re-run jobs*).

---

## 10. Como funciona o CI/CD (os dois workflows)

### `.github/workflows/ci.yml` — validação
Roda em **Pull Requests** e branches diferentes de `main`. Garante que:
- o site builda e passa no lint;
- o Terraform está formatado (`fmt -check`) e válido (`validate`).

### `.github/workflows/deploy.yml` — publicação
Roda no **push para `main`**. Faz build + sync + invalidação, autenticando via
**OIDC** (note o bloco `permissions: id-token: write`, obrigatório).

> 🔐 **Por que OIDC e não uma access key nos secrets?** Uma access key é uma
> credencial de longa duração: se vazar, vale até alguém revogar. Com OIDC, o
> GitHub gera um token de curtíssima duração a cada execução e a AWS o troca por
> credenciais temporárias. Nada sensível fica guardado no repositório.

---

## 11. Custos & free tier

Para um portfólio com pouco tráfego, o custo esperado é **US$ 0,00**:

- **CloudFront:** 1 TB/mês de saída grátis (permanente). Um site pequeno usa
  alguns MB.
- **S3:** poucos MB armazenados; requests irrisórios.
- **DynamoDB:** usado só durante `plan`/`apply`; muito abaixo do free tier.
- **IAM / OIDC / CloudFront Functions:** sem custo.

✅ **Recomendado:** mantenha o **AWS Budget** do passo 5.1 ativo.

---

## 12. Atualizar o site

Basta editar o código em `web/` e dar push na `main`. O pipeline cuida do resto.

```bash
# edite web/src/app/page.tsx ...
git commit -am "conteúdo novo"
git push origin main          # dispara o deploy automático
```

Para mudar **infra** (ex.: política de cache do CloudFront), edite os `.tf` e
rode `terraform apply` em `terraform/infra` (ou crie um workflow de
`terraform plan` em PRs — uma boa evolução futura).

---

## 13. Destruir tudo (evitar qualquer cobrança)

Na ordem inversa da criação:

```bash
# 1) Esvaziar o bucket do site (sync --delete não apaga o bucket)
aws s3 rm "s3://$(cd terraform/infra && terraform output -raw site_bucket_name)" --recursive

# 2) Destruir a infra
cd terraform/infra && terraform destroy

# 3) Destruir o bootstrap
#    Obs: o bucket de estado tem prevent_destroy=true. Para removê-lo, primeiro
#    edite main.tf tirando o lifecycle, ou esvazie e apague pelo console.
cd ../bootstrap && terraform destroy
```

---

## 14. Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| `BucketAlreadyExists` no bootstrap | Nome de bucket já usado por outra conta | Troque `state_bucket_name` e o `bucket` do `backend.tf` |
| `Error: Failed to get existing workspaces ... AccessDenied` no `init` da infra | Backend S3 não existe ainda / credencial errada | Rode o bootstrap primeiro; confira `aws sts get-caller-identity` |
| Deploy falha em "Configurar credenciais AWS" | Role OIDC não existe ou `AWS_ROLE_ARN` errado | Rode `terraform apply` na infra e revise as variáveis do repo |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | `sub` da trust policy não bate com o repo | Confira `github_owner`/`github_repo` em `variables.tf` |
| Site abre mas mostra XML/AccessDenied | Cache antigo / OAC ainda propagando | Aguarde e invalide o cache (`/*`) |
| Página 404 em subrota | Função de rewrite não associada | Confirme `function_association` no `cloudfront.tf` |

---

## 15. Próximos passos (ideias para evoluir o portfólio)

- [ ] Workflow de `terraform plan` comentando o diff direto no PR.
- [ ] Domínio próprio + ACM (certificado) + Route 53.
- [ ] Headers de cache otimizados (assets imutáveis vs. HTML sempre revalidado).
- [ ] Ambiente de `staging` separado (workspaces ou outra pasta).
- [ ] `terraform test` ou checagens com `tflint` / `checkov` no CI.
```
