#Deprecated configuration for create a s3 bucket website resource
#  resource "aws_s3_bucket" "frontend_artifacts" {
#   bucket = var.S3FrontEnd
#   acl    = "public-read"
#   policy = data.aws_iam_policy_document.website_policy.json
#   website {
#     index_document = "index.html"
#     error_document = "index.html"
#   }
# }
resource "aws_s3_bucket" "frontend_artifacts" {
  bucket = var.S3FrontEnd
}
data "aws_s3_bucket" "selected-bucket" {
  bucket = aws_s3_bucket.frontend_artifacts.bucket
}

resource "aws_s3_bucket_acl" "bucket-acl" {
  bucket = data.aws_s3_bucket.selected-bucket.id
  acl    = "public-read"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = data.aws_s3_bucket.selected-bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "bucket-policy" {
  bucket = data.aws_s3_bucket.selected-bucket.id
  policy = data.aws_iam_policy_document.website_policy.json
}
data "aws_iam_policy_document" "website_policy" {
  statement {
    sid    = "AllowPublicRead"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    resources = [
      "arn:aws:s3:::${var.S3FrontEnd}/*"
    ]
  }

  depends_on = [aws_s3_bucket_public_access_block.example]
}

resource "aws_s3_bucket_website_configuration" "frontend_artifacts" {
   bucket = data.aws_s3_bucket.selected-bucket.bucket

   index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
  
}
# data "aws_iam_policy_document" "website_policy" {
#   statement {
#     sid    = "AllowPublicRead"
#     effect = "Allow"
#     actions = [
#       "s3:GetObject"
#     ]
#     principals {
#       identifiers = ["*"]
#       type        = "AWS"
#     }
#     resources = [
#       "arn:aws:s3:::${var.S3FrontEnd}/*"
#     ]
#   }
# }
resource "aws_codebuild_project" "tf-frontend1" {
  name         = "cicd-build-${var.name_frontend}"
  description  = "pipeline for aplicacion frontend"
  service_role = var.codebuild_role

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      type  = "PLAINTEXT"
      name  = "S3_BUCKET_URL"
      value = aws_s3_bucket_website_configuration.frontend_artifacts.id
    }
  }
  source {
    type      = "CODEPIPELINE" #BITBUCKET
    buildspec = file("2-frontend/buildspec.yml")
  }
}
resource "aws_codepipeline" "frontend1_pipeline" {

  name     = "cicd-${var.name_frontend}"
  role_arn = var.codepipeline_role

  artifact_store {
    type     = "S3"
    location = var.s3_terraform_pipeline
  }

  stage {
    name = "Source"
    action {
      name     = "Source"
      category = "Source"
      owner    = "AWS"
      provider = "CodeStarSourceConnection"
      version  = "1"
      output_artifacts = [
        "SourceArtifact",
      ]
      configuration = {
        FullRepositoryId     = "rushqui/angular-website-example"
        BranchName           = "master"
        ConnectionArn        = var.codestar_connector_credentials
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Plan"
    action {
      name     = "Build"
      category = "Build"
      provider = "CodeBuild"
      version  = "1"
      owner    = "AWS"
      input_artifacts = [
        "SourceArtifact",
      ]

      output_artifacts = [
        "BuildArtifact",
      ]
      configuration = {
        ProjectName = "cicd-build-${var.name_frontend}"
      }
    }
  }
  stage {
    name = "Deploy"

    action {
      category = "Deploy"
      configuration = {
        "BucketName" = aws_s3_bucket_website_configuration.frontend_artifacts.id
        "Extract"    = "true"
      }
      input_artifacts = [
        "BuildArtifact",
      ]
      name             = "Deploy"
      output_artifacts = []
      owner            = "AWS"
      provider         = "S3"
      run_order        = 1
      version          = "1"
    }
  }


}
