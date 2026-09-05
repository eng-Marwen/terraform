terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.2.0"
    }
  }
}

provider "docker" {
#   host = "unix:///var/run/docker.sock" #local docker daemon

  registry_auth {
    address  = "registry-1.docker.io"
    username = var.dockerhub_username
    password = var.dockerhub_token
  }
}