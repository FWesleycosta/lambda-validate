variable "environment" {
  description = "Nome do ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "function_name_prefix" {
  description = "Nome único da função Lambda"
  type        = string
}

variable "description" {
  description = "Descrição da função Lambda"
  type        = string
  default     = "Microsserviço Serveless"
}

variable "lambda_timeout" {
  description = "Timeout da função Lambda em segundos"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memória alocada para a função Lambda em MB"
  type        = number
  default     = 128
}

variable "lambda_tracing_config" {
  description = "Configuração de tracing (PassThrough ou Active)"
  type        = string
  default     = "PassThrough"
}

variable "lambda_runtime" {
  description = "Runtime da função Lambda"
  type        = string
  default     = "dotnet10"
}

variable "environment_variables" {
  description = "Variáveis de ambiente da função Lambda"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs no CloudWatch"
  type        = number
  default     = 14
}

variable "dead_letter_target_arn" {
  description = "ARN da fila SQS ou tópico SNS para Dead Letter Queue"
  type        = string
  default     = null
}

variable "additional_policy_arns" {
  description = "Lista de ARNs de políticas IAM adicionais para a role da Lambda"
  type        = list(string)
  default     = []
}

variable "allowed_triggers" {
  description = "Mapa de triggers permitidos para invocar a Lambda"
  type = map(object({
    principal  = string
    source_arn = string
  }))
  default = {}
}

variable "handlers" {
  description = "Map de handler por lambda. Único campo que varia entre os lambdas."
  type        = map(string)
  default     = {}
}

variable "zip_filename" {
  type        = string
  description = "Nome do zip gerado pela pipeline — igual para todos os lambdas do projeto"
}

variable "AWS_REGION" {
  type = string
}

variable "subnets_privates" {
  type = list(string)
  default = ["subnet-0a07f6f5cfcbd75fe","subnet-07b8d1a2707ae9a5b"]
}

variable "app_name" {
  description = "Nome da aplicação (vem do repositório)"
  type = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type = string
}

variable "ssm_parameters" {
  type = map(object({
    name = string
    value = string
  }))
  default = {}
}
