resource "docker_container" "frontend" {
  name = "frontend_container"
  image = docker_image.frontend_image.image_id
  networks_advanced {
    name = docker_network.microservices_network.name
  }

  ports {
    internal = 80
    external = 8081
  }

    env = [
    "API_URL=${var.api_url}",
    "AI_API_URL=${var.ai_api_url}",
    "FIREBASE_API_KEY=${var.firebase_api_key}"
  ]
}

resource "docker_container" "backend" {
  name = "backend_container"
  image = docker_image.backend_image.image_id
  networks_advanced {
    name = docker_network.microservices_network.name
  }

  ports {
    internal = 4000
    external = 4000
  }

    env=[
    "REDIS_URL=${var.redis_url}",
    "RABBITMQ_URL=${var.rabbitmq_url}",
    "CLIENT_URL=${var.client_url}",
    "NODE_ENV=${var.node_env}",
    "PORT=${var.backend_port}",
    "SECRET_KEY=${var.jwt_secret_key}",
    "MONGODB_CONNECTION_STRING=${var.mongo_connection_string}",
    "MAILJET_API_KEY=${var.mailjet_api_key}",
    "MAILJET_SECRET_KEY=${var.mailjet_secret_key}",
    "CLOUDINARY_CLOUD_NAME=${var.cloudinary_cloud_name}",
    "CLOUDINARY_API_KEY=${var.cloudinary_api_key}",
    "CLOUDINARY_API_SECRET=${var.cloudinary_api_secret}"

  ]
  
}

resource "docker_container" "aimicroservice" {
  name = "aimicroservice_container"
  image = docker_image.aimicroservice_image.image_id
  networks_advanced {
    name = docker_network.microservices_network.name
  }

  ports {
    internal = 8000
    external = 8000
  }

    env=[
    "GROQ_API_KEY=${var.groq_api_key}",
    "GROQ_MODEL=${var.groq_model}",
    "JINA_API_KEY=${var.jina_api_key}",
    "RABBITMQ_URL=${var.rabbitmq_url}",
    "CLIENT_URL=${var.client_url}",
    "QDRANT_URL=${var.qdrant_url}",
    "REDIS_URL=${var.redis_url}",
    "RENT_MODEL_URL=${var.rent_model_url}",
    "SALE_MODEL_URL=${var.sale_model_url}",
    "VALIDATION_MODEL_URL=${var.validation_model_url}"
  ]
}

resource "docker_container" "redis" {
  name = "redis_container"
  image = docker_image.redis_image.image_id
  networks_advanced {
    name = docker_network.microservices_network.name
  }

  ports {
    internal = 6379
    external = 6379
  }
}

resource "docker_container" "rabbitmq" {
  name = "rabbitmq_container"
  image = docker_image.rabbitmq_image.image_id
  networks_advanced {
    name = docker_network.microservices_network.name
  }

  ports {
    internal = 5672
    external = 5672
  }
}

resource "docker_container" "qdrant" {
  name = "qdrant_container"
  image = docker_image.qdrant_image.image_id
  networks_advanced {
    name = docker_network.microservices_network.name
  }

  ports {
    internal = 6333
    external = 6333
  }
}


