# Portfólio — Next.js na AWS com Terraform + CI/CD

Site estático (Next.js + TypeScript) hospedado na AWS com infraestrutura 100%
em **Terraform** e deploy contínuo via **GitHub Actions** — tudo dentro do
**free tier**.

> 📘 O passo a passo completo (conta AWS, bootstrap, infra, deploy, custos) está
> em **[DOCUMENTATION.md](DOCUMENTATION.md)**.

## Stack

- **Next.js + TypeScript** — site exportado como estático (`output: "export"`)
- **AWS S3** — bucket privado de origem
- **AWS CloudFront** — CDN global com HTTPS grátis (acesso via OAC)
- **Terraform** — toda a infra como código (backend remoto S3 + lock DynamoDB)
- **GitHub Actions** — CI (build/lint/validate) e CD (deploy via OIDC, sem chave fixa)

## Arquitetura

```
git push main → GitHub Actions → (OIDC) → AWS
                     │
              build Next.js (out/)
                     │
                     ▼
        S3 (privado) ◀── CloudFront (CDN + HTTPS) ──▶ usuário
```

## Estrutura

```
web/                     # aplicação Next.js
terraform/bootstrap/     # bucket de estado + lock DynamoDB (roda 1x)
terraform/infra/         # S3 + CloudFront + OAC + OIDC/IAM
.github/workflows/       # ci.yml e deploy.yml
```

## Rodar o site localmente

```bash
cd web
npm install
npm run dev      # http://localhost:3000
```

## Subir a infra (resumo)

```bash
cd terraform/bootstrap && terraform init && terraform apply
cd ../infra            && terraform init && terraform apply
# configure as Repository Variables no GitHub e dê push na main
```

Detalhes em [DOCUMENTATION.md](DOCUMENTATION.md).
