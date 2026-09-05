#download the docker provider kreuzwerker/docker from the terraform registry during terraform init
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.2.0"
    }
  }
}

#Docker provider communicates with the Docker Engine through the Docker API.
provider "docker" {}
