terraform {
  required_version = "1.1.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
}

# Remote state
terraform {
  backend "s3" {
    endpoint = "fra1.digitaloceanspaces.com"
    region   = "eu-central-1"
    key      = "terraform.tfstate"
    bucket   = "k8s-spaces"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}
