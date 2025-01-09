variable "S3FrontEnd"{
    type = string
        default = null
}
variable "name_frontend"{
    type = string
        default = null
}

variable "codebuild_role"{
    type = string
    default = null
}
variable "codepipeline_role"{
    type = string
        default = null
}
variable "s3_terraform_pipeline"{
    type = string
        default = null
}
variable "codestar_connector_credentials"{
    type = string
    default = null
}