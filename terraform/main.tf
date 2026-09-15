##############################
#   IAM Role for Lambda
##############################
module "lambda_role" {
  source = "git::https://dev.azure.com/bancofibra/Fibra.DevOps/_git/Fibra.DevOps.Terraform//modules/aws_iam_role"

  for_each = var.handlers

  function_name = "${var.function_name_prefix}-${each.key}"

  additional_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]

  app_name = var.function_name_prefix

  tags = merge(local.definitions, {
    "Aplicacao" = "${var.function_name_prefix}-${each.key}"
  })
}

##############################
#   Security Group for Lambda
##############################
module "lambda_security_group" {
  source = "git::https://dev.azure.com/bancofibra/Fibra.DevOps/_git/Fibra.DevOps.Terraform//modules/aws_security_groups"

  create_security_group = true

  name        = var.function_name_prefix
  description = "Security Group para Lambdas: ${var.function_name_prefix}"
  vpc_id      = data.aws_vpc.selected.id

  ingress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.selected.cidr_block]
      description = "Allow HTTPS traffic"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound (SSM, APIs)"
    }
  ]

  tags = merge(local.definitions, {
    "Aplicacao" = var.function_name_prefix
  })
}

##############################
#   Lambda Functions
##############################
module "lambda" {
  source = "git::https://dev.azure.com/bancofibra/Fibra.DevOps/_git/Fibra.DevOps.Terraform//modules/aws_lambda_function"

  for_each = var.handlers

  create_lambda_function = true

  function_name    = "${var.function_name_prefix}-${each.key}"
  description      = var.description
  role             = module.lambda_role[each.key].role_arn
  handler          = each.value
  runtime          = var.lambda_runtime
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  tracing_config   = var.lambda_tracing_config
  package_type     = "Zip"
  filename         = "./zip/${var.zip_filename}.zip"
  source_code_hash = filebase64sha256("./zip/${var.zip_filename}.zip")

  environment        = {}
  subnet_ids         = var.subnets_privates
  security_group_ids = [module.lambda_security_group.security_group_id]

  tags = merge(local.definitions, {
    "Aplicacao" = "${var.function_name_prefix}-${each.key}"
  })

  depends_on = [module.lambda_security_group, module.lambda_role]
}

##############################
#   SQS Salvar (com DLQ)
##############################
module "aws_sqs_salvar_dlq" {
  source     = "git::https://dev.azure.com/bancofibra/Fibra.DevOps/_git/Fibra.DevOps.Terraform//modules/aws_sqs_dlq"
  queue_name = "sqs-${var.environment}-${var.AWS_REGION}-operacoes-boletador-salvar"

  tags = merge(local.definitions, {
    "Aplicacao" = var.function_name_prefix
  })
}

module "aws_sqs_salvar" {
  source = "git::https://dev.azure.com/bancofibra/Fibra.DevOps/_git/Fibra.DevOps.Terraform//modules/aws_sqs_queue"

  queue_name = "sqs-${var.environment}-${var.AWS_REGION}-operacoes-boletador-salvar"
  fifo_queue = false

  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  dlq_arn           = module.aws_sqs_salvar_dlq.dlq_arn
  max_receive_count = 3

  tags = merge(local.definitions, {
    "Aplicacao" = var.function_name_prefix
  })

  depends_on = [module.aws_sqs_salvar_dlq]
}

##############################
#   SQS Falha gravação sacado (sem DLQ) — ACL publica uma mensagem por sacado com falha
##############################
module "aws_sqs_sacado_falha" {
  source = "git::https://dev.azure.com/bancofibra/Fibra.DevOps/_git/Fibra.DevOps.Terraform//modules/aws_sqs_queue"

  queue_name = "sqs-${var.environment}-${var.AWS_REGION}-operacoes-boletador-sacado-falha"
  fifo_queue = false

  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  tags = merge(local.definitions, {
    "Aplicacao" = var.function_name_prefix
  })
}

##############################
#   SNS Resultado do Boleto
##############################
module "aws_sns_salvar_resultado" {
  source = "git::https://dev.azure.com/bancofibra/Fibra.DevOps/_git/Fibra.DevOps.Terraform//modules/aws_sns_topic"

  topic_name = "sns-${var.environment}-${var.AWS_REGION}-operacoes-boletador-salvar-resultado"
  fifo_topic                  = false
  content_based_deduplication = false

  tags = merge(local.definitions, {
    "Aplicacao" = var.function_name_prefix
  })
}

##############################
#   Step Function Salvar
##############################
module "aws_step_function_salvar" {
  source = "git::https://dev.azure.com/bancofibra/Fibra.DevOps/_git/Fibra.DevOps.Terraform//modules/aws_step_functions"

  name = "${var.function_name_prefix}-boleto-salvar"

  # Definição ASL unica em infra/sf-boleto-salvar-workflow.asl.json (parametrizada por ambiente via templatefile).
  definition = templatefile("${path.module}/../infra/sf-boleto-salvar-workflow.asl.json", {
    environment                  = var.environment
    iniciar_processamento_arn    = local.lambda_function_arns["iniciar-processamento"]
    salvar_sybase_arn            = local.lambda_function_arns["salvar-sybase"]
    salvar_pg_arn                = local.lambda_function_arns["salvar-pg"]
    salvar_dados_ted_sybase_arn  = local.lambda_function_arns["salvar-dados-ted-sybase"]
    salvar_dados_ted_pg_arn      = local.lambda_function_arns["salvar-dados-ted-pg"]
    salvar_garantia_garantidor_arn = local.lambda_function_arns["salvar-garantia-garantidor"]
    preparar_paginas_titulos_arn = local.lambda_function_arns["preparar-paginas-titulos"]
    salvar_lote_titulos_sybase_arn = local.lambda_function_arns["salvar-lote-titulos-sybase"]
    salvar_lote_titulos_pg_arn   = local.lambda_function_arns["salvar-lote-titulos-pg"]
    preparar_paginas_sacados_arn = local.lambda_function_arns["preparar-paginas-sacados"]
    salvar_lote_sacados_sybase_arn = local.lambda_function_arns["salvar-lote-sacados-sybase"]
    agregar_mapa_sacados_arn     = local.lambda_function_arns["agregar-mapa-sacados"]
    vincular_sacados_titulos_sybase_arn = local.lambda_function_arns["vincular-sacados-titulos-sybase"]
    vincular_sacados_titulos_pg_arn = local.lambda_function_arns["vincular-sacados-titulos-pg"]
    compensar_boleto_arn         = local.lambda_function_arns["compensar-boleto"]
    atualizar_status_arn         = local.lambda_function_arns["atualizar-status"]
    notificar_tesouraria_arn     = local.lambda_function_arns["notificar-tesouraria"]
    sns_salvar_resultado_arn     = module.aws_sns_salvar_resultado.topic_arn
  })

  app_name = var.function_name_prefix

  tags = merge(local.definitions, {
    "Aplicacao" = var.function_name_prefix
  })

  depends_on = [module.lambda, module.aws_sns_salvar_resultado]
}

##############################
#   EventBridge Pipe (SQS Entrada → Step Function)
#   O módulo aws_pipe_pipe não expõe target_parameters.input_template; o input da SF é o
#   envelope da mensagem SQS (ex.: messageId, body string JSON). O ASL desembrulha $.body
#   antes de IniciarProcessamento (Pass + States.StringToJson). O CorrelationId segue
#   dentro do body (SalvarBoletoRequestDto), propagado pelo Boletador API ao publicar na SQS.
##############################
module "aws_eventbridge" {
  source = "git::https://dev.azure.com/bancofibra/Fibra.DevOps/_git/Fibra.DevOps.Terraform//modules/aws_pipe_pipe"

  pipe_name  = "boleto-salvar"
  source_arn = module.aws_sqs_salvar.queue_arn
  target_arn = module.aws_step_function_salvar.state_machine_arn

  source_parameters = {
    sqs = {
      batch_size                         = 1
    }
  }

  target_parameters = {
    sfn = {
      invocation_type = "FIRE_AND_FORGET"
    }
  }

  app_name = var.function_name_prefix

  tags = merge(local.definitions, {
    Aplicacao = var.function_name_prefix
  })

  depends_on = [module.aws_sqs_salvar, module.aws_step_function_salvar]
}

##############################
#   SSM Parameters
##############################
module "aws_ssm_parameters" {

  for_each = var.ssm_parameters

  source = "git::https://dev.azure.com/bancofibra/Fibra.DevOps/_git/Fibra.DevOps.Terraform//modules/aws_parameter_store"

  name = each.value.name
  value = each.value.value
  type = "String"

  tags = merge(local.tags, {
    Aplicacao = var.function_name_prefix
  })
}
