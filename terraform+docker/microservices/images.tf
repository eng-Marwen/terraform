resource "docker_image" "frontend_image" {
  name= "engmarwen/samsar:frontend-1.1.2"
}

resource "docker_image" "backend_image" {
  name= "engmarwen/samsar:backend-2.0.6"
}

resource "docker_image" "aimicroservice_image" {
  name= "engmarwen/samsar:aiMicroservice-0.2.5"
}

resource "docker_image" "rabbitmq_image" {
  name= "rabbitmq:3-management"
}

resource "docker_image" "qdrant_image" {
  name= "qdrant/qdrant:latest"
}

resource "docker_image" "redis_image" {
  name= "redis:7-alpine"
}