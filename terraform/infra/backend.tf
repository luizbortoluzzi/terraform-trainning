###############################################################################
# BACKEND REMOTO
#
# Diz ao Terraform para guardar o estado no bucket S3 criado pelo bootstrap,
# com lock via DynamoDB. ATENÇÃO: os valores aqui NÃO aceitam variáveis
# (limitação do Terraform), então precisam bater exatamente com o que o
# bootstrap criou.
###############################################################################

terraform {
  backend "s3" {
    bucket         = "luizbortoluzzi-tfstate-portfolio"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-portfolio"
    encrypt        = true
  }
}
