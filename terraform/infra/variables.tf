variable "aws_region" {
  description = "Região AWS onde o bucket do site será criado (a entrega é global via CloudFront)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado em nomes de recursos e tags."
  type        = string
  default     = "terraform-trainning"
}

variable "site_bucket_name" {
  description = "Nome do bucket S3 que guarda os arquivos do site. PRECISA ser único no mundo."
  type        = string
  default     = "luizbortoluzzi-terraform-trainning"
}

variable "github_owner" {
  description = "Dono do repositório no GitHub (usuário ou organização)."
  type        = string
  default     = "luizbortoluzzi"
}

variable "github_repo" {
  description = "Nome do repositório no GitHub que terá permissão de deploy via OIDC."
  type        = string
  default     = "terraform-trainning"
}
