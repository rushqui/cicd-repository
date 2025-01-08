terraform{
    backend "s3" {
        bucket = "terraform-state-eliasr"
        encrypt = true
        key = "terraform1.tfstate"
        region = "us-east-1"
    }
}

provider "aws" {
  region  = "us-east-1"
}
