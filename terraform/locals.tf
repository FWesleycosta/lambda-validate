locals {
  definitions = {
    Environment = var.environment
    Created_at  = formatdate("DD-MM-YYYY HH:mm:ss 'BRT'", timeadd(timestamp(), "-3h"))
    ManagedBy   = "Terraform"
  }

  tags = merge(local.definitions, {
    Aplicacao = var.app_name
  })

  # ARN completo das Lambdas (Step Functions exige ARN em FunctionName para evitar warning na console AWS).
  lambda_function_arns = {
    for handler_key, _ in var.handlers :
    handler_key => "arn:aws:lambda:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:function:${var.function_name_prefix}-${handler_key}"
  }
}

 
