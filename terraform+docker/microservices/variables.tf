#=======dockerhub credentials========

variable "dockerhub_username" {
  type = string
  default = "engmarwen"
}
variable "dockerhub_token" {
  type = string
  description = "access token read write"
  sensitive = true
}

#=======frontend variables========
variable "api_url" {
  type = string
  default = "http://localhost:4000"
}
variable "ai_api_url" {
  type = string
  default = "http://localhost:8000"
}
variable "firebase_api_key" {
  type = string
  sensitive = true
}

#=======backend variables========
variable "backend_port" {
  type = number
  default = 4000
}
variable "node_env" {
  type = string
  default = "production"
}

variable "jwt_secret_key" {
  type=string
  sensitive = true
}

variable "mongo_connection_string" {
  type = string
  sensitive = true
}
#emails
variable "mailjet_api_key" {
  type = string
  sensitive = true
}
variable "mailjet_secret_key" {
  type = string
  sensitive = true
}
#cloudinary
variable "cloudinary_cloud_name" {
  type = string
  default = "dgmaxi7wu"
}
variable "cloudinary_api_key" {
  type = string
  sensitive = true
}
variable "cloudinary_api_secret" {
  type = string
  sensitive = true
}

variable "redis_url" {
  type = string
  default = "redis://redis_container:6379"
}
variable "rabbitmq_url" {
  type = string
  default = "amqp://rabbitmq_container:5672"
}
variable "client_url" {
  type = string
  default = "http://localhost:8081"
}

variable "qdrant_url" {
  type = string
  default = "http://qdrant_container:6333"
  
}

#=======aimicroservice variables========

variable "groq_api_key" {
  type = string
  sensitive = true
}
variable "groq_model" {
  type = string
  default = "openai/gpt-oss-120b"
}
variable "jina_api_key" {
  type = string 
  sensitive = true
}
variable "rent_model_url" {
  type = string
  default = "https://drive.google.com/uc?export=download&id=1y3SH-R3qtTIuYlLyvlHr7pbRjxVLYqCi"
}
variable "sale_model_url" {
  type = string
  default = "https://drive.google.com/uc?export=download&id=1lXyaSf5ZAQtmFr0zZ0ntlBoYpWZLsF1V"
}
variable "validation_model_url" {
  type = string
  default = "https://drive.google.com/uc?export=download&id=1BuXcG-ihbuBrGeBU2dkyEMra8oOK1gZ6"
}
