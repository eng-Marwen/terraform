# Frontend
output "frontend_url" {
  description = "URL to access the frontend"
  value       = "http://localhost:${docker_container.frontend.ports[0].external}"
}

# Backend
output "backend_url" {
  description = "URL to access the backend"
  value       = "http://localhost:${docker_container.backend.ports[0].external}"
}

# AI Microservice
output "ai_microservice_url" {
  description = "URL to access the AI microservice"
  value       = "http://localhost:${docker_container.aimicroservice.ports[0].external}"
}

# Container names
output "container_names" {
  description = "Names of all Docker containers managed by Terraform"
  value = [
    docker_container.frontend.name,
    docker_container.backend.name,
    docker_container.aimicroservice.name,
    docker_container.redis.name,
    docker_container.rabbitmq.name,
    docker_container.qdrant.name
  ]
}