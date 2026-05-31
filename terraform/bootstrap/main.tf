###############################################################################
# BOOTSTRAP
#
# Cria a infraestrutura que ARMAZENA o estado do Terraform:
#   - 1 bucket S3 (guarda o arquivo terraform.tfstate, versionado e criptografado)
#   - 1 tabela DynamoDB (faz o "lock" pra dois `apply` não rodarem ao mesmo tempo)
#
# Este módulo usa ESTADO LOCAL (terraform.tfstate aqui na pasta), porque o
# backend remoto ainda não existe no momento em que rodamos isto. É o clássico
# problema do ovo-e-a-galinha. Roda uma vez e raramente muda.
###############################################################################

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Tags aplicadas a todo recurso criado por este provider — ótimo pra
  # rastrear custos e saber o que é do projeto.
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Module    = "bootstrap"
    }
  }
}

# ---------------------------------------------------------------------------
# Bucket S3 que guarda o estado do Terraform
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  # Proteção contra `terraform destroy` apagar o bucket de estado sem querer.
  lifecycle {
    prevent_destroy = true
  }
}

# Versionamento: mantém histórico do estado. Se um apply corromper algo,
# dá pra voltar a uma versão anterior.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Criptografia em repouso (SSE-S3 / AES256), sem custo extra.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueia QUALQUER acesso público ao bucket de estado.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# Tabela DynamoDB pro lock do estado
# ---------------------------------------------------------------------------
# PAY_PER_REQUEST = cobra por uso. Como o lock é usado só durante apply/plan,
# o uso é mínimo e fica dentro do free tier.
resource "aws_dynamodb_table" "tflock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
