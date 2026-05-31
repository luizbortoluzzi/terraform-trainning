# 📘 Documentation — Next.js Portfolio on AWS with Terraform + CI/CD

This document explains, **step by step**, how this project was built and how to
get it live. The idea is to serve both as a portfolio and as study material for
**Terraform**, **AWS**, and **CI/CD with GitHub Actions** — all within AWS's
**free tier**.

---

## 1. Overview

A static site (Next.js + TypeScript) hosted on AWS, with infrastructure
100% described in Terraform and automatic deployment on every push to `main`.

### Architecture

```
 You (git push main)
        │
        ▼
 ┌─────────────────────┐     OIDC (temporary token, no static key)
 │   GitHub Actions     │ ─────────────────────────────────────────┐
 │  1. build Next.js    │                                           ▼
 │  2. aws s3 sync       │                                  ┌──────────────┐
 │  3. invalidate CF     │ ────────────────────────────────▶│  AWS (account)│
 └─────────────────────┘                                   └──────────────┘
                                                                   │
                  ┌────────────────────────────────────────────────┤
                  ▼                                                  ▼
        ┌──────────────────┐   OAC (private)        ┌────────────────────────┐
        │  S3 (site        │◀───────────────────────│  CloudFront (CDN+HTTPS) │
        │  bucket, PRIVATE)│                         └────────────────────────┘
        └──────────────────┘                                       │
                                                                   ▼
                                                        end user accesses
                                                       https://xxxx.cloudfront.net
```

### Why each piece?

| Component | Role | Why it's free (free tier) |
|---|---|---|
| **S3** | Stores the site's files (private bucket) | 5 GB free for 12 months; then cents for a small site |
| **CloudFront** | Global CDN + free HTTPS | 1 TB of transfer/month free (permanent) |
| **OAC** | Lets only CloudFront read S3 | No cost |
| **DynamoDB** | Terraform state lock | 25 GB free (permanent); minimal usage |
| **IAM + OIDC** | Deploy without a static key | No cost |
| **GitHub Actions** | CI/CD pipeline | Free for public repositories |

> 💡 We don't use a custom domain (Route 53 costs US$ 0.50/month per hosted zone).
> We access it through the default `*.cloudfront.net` URL, which already comes with
> free HTTPS.

---

## 2. Repository structure

```
terraform-trainning/
├── DOCUMENTATION.md            ← this file
├── README.md
├── .gitignore                  ← ignores tfstate, node_modules, secrets
├── web/                        ← Next.js + TypeScript application (i18n: en/pt)
│   ├── src/app/page.tsx        ← root "/" → redirects to the default locale
│   ├── src/app/[locale]/page.tsx   ← the portfolio page (per language)
│   ├── src/messages/{en,pt}.json   ← translation catalogs
│   ├── src/i18n/               ← next-intl config (routing, request)
│   ├── next.config.ts          ← output: "export" (generates static site)
│   └── ...
├── terraform/
│   ├── bootstrap/              ← creates the state bucket + lock (runs once)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── infra/                  ← S3 + CloudFront + OAC + OIDC/IAM
│       ├── backend.tf          ← remote state in S3
│       ├── providers.tf
│       ├── variables.tf
│       ├── s3.tf
│       ├── cloudfront.tf
│       ├── github_oidc.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
└── .github/workflows/
    ├── ci.yml                  ← validates build + Terraform on PRs
    └── deploy.yml              ← publishes to AWS on push to main
```

---

## 3. Prerequisites

| Tool | Version used | How to check |
|---|---|---|
| Node.js | 20+ (here: v24) | `node --version` |
| Terraform | 1.6+ (here: v1.15.5) | `terraform version` |
| AWS CLI | v2 (here: v2.34) | `aws --version` |
| AWS account | — | console access |
| GitHub account | — | repository created |

> The tools (Terraform and AWS CLI) were installed in `~/.local/bin` so as not
> to require `sudo`. If you redo this on another machine, download Terraform
> from [releases.hashicorp.com](https://releases.hashicorp.com/terraform/)
> and the AWS CLI from [aws.amazon.com/cli](https://aws.amazon.com/cli/).

---

## 4. The Next.js app (the easy part)

The site is a Next.js app created with `create-next-app` (TypeScript + Tailwind),
with one key change in [`web/next.config.ts`](web/next.config.ts):

```ts
const nextConfig: NextConfig = {
  output: "export",          // generates plain HTML/CSS/JS in the out/ folder
  images: { unoptimized: true },
  trailingSlash: true,       // /route/ -> /route/index.html
};
```

`output: "export"` is what allows running Next **without a Node server** — it
becomes a handful of static files, perfect for S3 + CloudFront.

### Internationalization (English + Portuguese)

The site is bilingual using [`next-intl`](https://next-intl.dev). Because a
static export has **no middleware**, i18n is done with a `[locale]` route
segment instead:

- `src/i18n/routing.ts` declares the locales (`en`, `pt`) and the default.
- `src/i18n/request.ts` loads the matching catalog from `src/messages/*.json`.
- `src/app/[locale]/layout.tsx` calls `generateStaticParams()` + `setRequestLocale()`,
  so `/en` and `/pt` are pre-rendered as static HTML at build time.
- `src/app/page.tsx` (root `/`) renders a `<meta refresh>` that forwards to the
  default locale — works even without JavaScript.
- A `LanguageSwitcher` client component swaps the language while keeping the path.

To add a language: add the locale to `routing.ts` and create its
`src/messages/<locale>.json`. That's it.

**Run locally:**

```bash
cd web
npm install
npm run dev        # http://localhost:3000  (development mode)
npm run build      # generates the web/out/ folder  (what goes to S3)
```

---

## 5. Set up the AWS account (one time)

> ⚠️ These steps are **manual in the AWS console** because they involve creating
> an account and credentials — things you cannot (and should not) automate.

### 5.1. Create the AWS account

1. Go to <https://aws.amazon.com/free> and create an account.
2. A credit card will be requested (AWS makes a symbolic verification charge and
   refunds it). Staying within the free tier, **there is no charge**.
3. Enable a **billing alert** for peace of mind:
   - Console → *Billing and Cost Management* → *Budgets* → create a budget of,
     for example, **US$ 1.00**, with email alerts. That way, if anything goes
     outside the free tier, you are notified immediately.

### 5.2. Create an IAM user for local use (don't use the root account!)

The "root" account (the email that created the account) is too powerful for
day-to-day use. Create a separate user:

1. Console → **IAM** → *Users* → *Create user*.
2. Name: `terraform-admin`.
3. For permissions, attach the managed policy **AdministratorAccess**
   (this is just for you to run Terraform from your machine; the CI deploy will
   use a much more restricted role).
4. After creation: *Security credentials* tab → *Create access key* →
   choose *Command Line Interface (CLI)* → copy the **Access key ID** and the
   **Secret access key**.

### 5.3. Configure the AWS CLI on your machine

```bash
aws configure
# AWS Access Key ID:     <paste here>
# AWS Secret Access Key: <paste here>
# Default region name:   us-east-1
# Default output format: json
```

Test:

```bash
aws sts get-caller-identity
# should show your Account ID and the ARN of the terraform-admin user
```

---

## 6. Bootstrap — create the Terraform state "vault"

Terraform stores what it created in a **state** file (`tfstate`).
In serious projects this file lives in an S3 bucket (shareable, versioned)
with a **lock** in DynamoDB (so two `apply` runs don't run at the same time).

But there's a chicken-and-egg problem: *who creates that bucket?* The
`bootstrap` module solves this — it creates the bucket + the table using
**local state**.

```bash
cd terraform/bootstrap

terraform init      # downloads the AWS provider
terraform plan      # shows what will be created (bucket + table)
terraform apply     # type "yes" to confirm
```

Expected output (outputs):

```
state_bucket_name = "luizbortoluzzi-terraform-trainning-tfstate"
lock_table_name   = "terraform-trainning-lock"
```

> 🔴 **The bucket name must be globally unique.** If you get a name-already-in-use
> error, edit `state_bucket_name` in
> [`terraform/bootstrap/variables.tf`](terraform/bootstrap/variables.tf) **and**
> the `bucket` in [`terraform/infra/backend.tf`](terraform/infra/backend.tf) to
> the same value.

---

## 7. Infra — S3 + CloudFront + OIDC

Now the main module. It uses the **remote backend** (the bucket we just
created) — see [`terraform/infra/backend.tf`](terraform/infra/backend.tf).

```bash
cd ../infra      # (from terraform/bootstrap)

terraform init   # connects to the S3 backend; it will say "Successfully configured the backend s3"
terraform plan   # review what will be created
terraform apply  # "yes" to confirm
```

This creates:

- The **site S3 bucket** (private);
- The **CloudFront distribution** with HTTPS;
- The **OAC** and the **bucket policy** linking the two;
- The **GitHub OIDC provider** and the deploy **IAM role**.

> ⏱️ CloudFront takes ~3–5 minutes to "deploy" the first time. This is normal.

Note down the **outputs** (we'll use them in GitHub):

```
cloudfront_url             = "https://d123abc.cloudfront.net"
cloudfront_distribution_id = "E1XXXXXXXXXXXX"
site_bucket_name           = "luizbortoluzzi-terraform-trainning"
github_actions_role_arn    = "arn:aws:iam::123456789012:role/terraform-trainning-github-actions"
```

To display them again later: `terraform output`.

---

## 8. Connect GitHub Actions to AWS (OIDC)

The deploy workflow needs to know 4 things. They are **not secret** (they're just
identifiers), so we use **Repository Variables** (not secrets).

### Through the GitHub interface

Repository → **Settings** → *Secrets and variables* → **Actions** → **Variables**
tab → *New repository variable*. Create all four:

| Variable name | Value (comes from the Terraform outputs) |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `AWS_ROLE_ARN` | the `github_actions_role_arn` |
| `AWS_S3_BUCKET` | the `site_bucket_name` |
| `AWS_CLOUDFRONT_DISTRIBUTION_ID` | the `cloudfront_distribution_id` |

### Or via the command line (gh CLI)

```bash
gh variable set AWS_REGION                     --body "us-east-1"
gh variable set AWS_ROLE_ARN                   --body "$(cd terraform/infra && terraform output -raw github_actions_role_arn)"
gh variable set AWS_S3_BUCKET                  --body "$(cd terraform/infra && terraform output -raw site_bucket_name)"
gh variable set AWS_CLOUDFRONT_DISTRIBUTION_ID --body "$(cd terraform/infra && terraform output -raw cloudfront_distribution_id)"
```

---

## 9. First deploy 🚀

With the infra up and the variables configured:

```bash
git add .
git commit -m "feat: site, Terraform infra and CI/CD"
git push origin main
```

Go to **Actions** on GitHub and follow the **Deploy** workflow. It will:

1. Build Next.js (`web/out`);
2. Assume the role via OIDC (without any stored key);
3. `aws s3 sync` to the bucket;
4. Invalidate the CloudFront cache.

When it finishes, open the `cloudfront_url`. **Site is live!** 🎉

> ⚠️ **Order matters:** run the infra `terraform apply` and configure the
> variables **before** relying on the deploy. If you push to main before the
> role exists, the deploy job fails — just run it again afterwards (the
> *Re-run jobs* button).

---

## 10. How the CI/CD works (the two workflows)

### `.github/workflows/ci.yml` — validation
Runs on **Pull Requests** and branches other than `main`. It ensures that:
- the site builds and passes lint;
- Terraform is formatted (`fmt -check`) and valid (`validate`).

### `.github/workflows/deploy.yml` — publishing
Runs on **push to `main`**. It does build + sync + invalidation, authenticating
via **OIDC** (note the `permissions: id-token: write` block, which is required).

> 🔐 **Why OIDC and not an access key in secrets?** An access key is a
> long-lived credential: if it leaks, it's valid until someone revokes it. With
> OIDC, GitHub generates a very short-lived token on each run and AWS exchanges
> it for temporary credentials. Nothing sensitive is stored in the repository.

---

## 11. Costs & free tier

For a portfolio with little traffic, the expected cost is **US$ 0.00**:

- **CloudFront:** 1 TB/month of egress free (permanent). A small site uses
  a few MB.
- **S3:** a few MB stored; negligible requests.
- **DynamoDB:** used only during `plan`/`apply`; well below the free tier.
- **IAM / OIDC / CloudFront Functions:** no cost.

✅ **Recommended:** keep the **AWS Budget** from step 5.1 active.

---

## 12. Update the site

Just edit the code in `web/` and push to `main`. The pipeline takes care of the rest.

```bash
# edit web/src/app/page.tsx ...
git commit -am "new content"
git push origin main          # triggers the automatic deploy
```

To change the **infra** (e.g. CloudFront cache policy), edit the `.tf` files and
run `terraform apply` in `terraform/infra` (or create a `terraform plan` workflow
on PRs — a good future improvement).

---

## 13. Destroy everything (avoid any charges)

In the reverse order of creation:

```bash
# 1) Empty the site bucket (sync --delete doesn't delete the bucket)
aws s3 rm "s3://$(cd terraform/infra && terraform output -raw site_bucket_name)" --recursive

# 2) Destroy the infra
cd terraform/infra && terraform destroy

# 3) Destroy the bootstrap
#    Note: the state bucket has prevent_destroy=true. To remove it, first
#    edit main.tf removing the lifecycle, or empty and delete it via the console.
cd ../bootstrap && terraform destroy
```

---

## 14. Troubleshooting

| Symptom | Likely cause | Solution |
|---|---|---|
| `BucketAlreadyExists` on bootstrap | Bucket name already used by another account | Change `state_bucket_name` and the `bucket` in `backend.tf` |
| `Error: Failed to get existing workspaces ... AccessDenied` on the infra `init` | S3 backend doesn't exist yet / wrong credential | Run the bootstrap first; check `aws sts get-caller-identity` |
| Deploy fails at "Configure AWS credentials" | OIDC role doesn't exist or wrong `AWS_ROLE_ARN` | Run `terraform apply` on the infra and review the repo variables |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The trust policy `sub` doesn't match the repo | Check `github_owner`/`github_repo` in `variables.tf` |
| Site opens but shows XML/AccessDenied | Stale cache / OAC still propagating | Wait and invalidate the cache (`/*`) |
| 404 page on a subroute | Rewrite function not associated | Confirm `function_association` in `cloudfront.tf` |

---

## 15. Next steps (ideas to evolve the portfolio)

- [ ] A `terraform plan` workflow commenting the diff directly on the PR.
- [ ] Custom domain + ACM (certificate) + Route 53.
- [ ] Optimized cache headers (immutable assets vs. always-revalidated HTML).
- [ ] A separate `staging` environment (workspaces or another folder).
- [ ] `terraform test` or checks with `tflint` / `checkov` in CI.
