# Portfolio — Next.js on AWS with Terraform + CI/CD

Static site (Next.js + TypeScript) hosted on AWS with 100% of the infrastructure
in **Terraform** and continuous deployment via **GitHub Actions** — all within
the **free tier**.

> 📘 The complete step-by-step guide (AWS account, bootstrap, infra, deploy, costs)
> is in **[DOCUMENTATION.md](DOCUMENTATION.md)**.

## Stack

- **Next.js + TypeScript** — site exported as static (`output: "export"`)
- **next-intl** — bilingual site (English + Portuguese) via a `[locale]` route segment
- **AWS S3** — private origin bucket
- **AWS CloudFront** — global CDN with free HTTPS (access via OAC)
- **Terraform** — all infrastructure as code (remote S3 backend + DynamoDB lock)
- **GitHub Actions** — CI (build/lint/validate) and CD (deploy via OIDC, no static key)

## Architecture

```
git push main → GitHub Actions → (OIDC) → AWS
                     │
              build Next.js (out/)
                     │
                     ▼
        S3 (private) ◀── CloudFront (CDN + HTTPS) ──▶ user
```

## Structure

```
web/                     # Next.js application
terraform/bootstrap/     # state bucket + DynamoDB lock (runs once)
terraform/infra/         # S3 + CloudFront + OAC + OIDC/IAM
.github/workflows/       # ci.yml and deploy.yml
```

## Run the site locally

```bash
cd web
npm install
npm run dev      # http://localhost:3000
```

## Provision the infra (summary)

```bash
cd terraform/bootstrap && terraform init && terraform apply
cd ../infra            && terraform init && terraform apply
# configure the Repository Variables on GitHub and push to main
```

Details in [DOCUMENTATION.md](DOCUMENTATION.md).
