###############################################################################
# OIDC GITHUB ACTIONS -> AWS  (deploy sem chave fixa)
#
# Em vez de guardar uma AWS_ACCESS_KEY_ID/SECRET nos secrets do GitHub (que
# vazam e não expiram), o GitHub Actions troca um token OIDC de curta duração
# por credenciais temporárias na AWS. Mais seguro e é boa prática moderna.
###############################################################################

# Registra o GitHub como provedor de identidade OIDC confiável na sua conta AWS.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # Thumbprints dos certificados do GitHub. A AWS hoje valida via biblioteca,
  # mas o provider ainda exige o campo preenchido.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# Política de confiança: só o GitHub, só este repositório, podem assumir a role.
data "aws_iam_policy_document" "github_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # O token tem que ter audience "sts.amazonaws.com".
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # E tem que vir DESTE repositório (qualquer branch/ref).
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  description        = "Role assumida pelo GitHub Actions para fazer deploy do site"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

# Permissões MÍNIMAS necessárias pro deploy: mexer nos objetos do bucket do
# site e invalidar o cache desta distribuição. Nada além disso.
data "aws_iam_policy_document" "deploy_permissions" {
  statement {
    sid       = "ListSiteBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }

  statement {
    sid = "WriteSiteObjects"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }

  statement {
    sid = "InvalidateCloudFront"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
    ]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.project_name}-deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.deploy_permissions.json
}
