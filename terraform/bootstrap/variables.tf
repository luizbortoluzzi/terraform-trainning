variable "aws_region" {
  description = "Região AWS onde o bucket de estado e a tabela de lock serão criados."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado em tags."
  type        = string
  default     = "portfolio-terraform"
}

variable "state_bucket_name" {
  description = "Nome do bucket S3 que guarda o tfstate. PRECISA ser único no mundo todo."
  type        = string
  default     = "luizbortoluzzi-tfstate-portfolio"
}

variable "lock_table_name" {
  description = "Nome da tabela DynamoDB usada para lock do estado."
  type        = string
  default     = "terraform-lock-portfolio"
}
