
locals {
  lambda_filename_without_suffix = "assign_tags_to_elastic_ip_addresses"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/assign_tags_to_elastic_ip_addresses__lambda.zip"

  source {
    content  = file("${path.module}/../scripts/assign_tags_to_elastic_ip_addresses.py")
    filename = "${local.lambda_filename_without_suffix}.py"
  }
}

resource "aws_lambda_function" "function" {
  function_name    = "${var.service_name_hyphens}--function"
  role             = aws_iam_role.lambda_role.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "${local.lambda_filename_without_suffix}.handler"
  runtime          = "python3.12"
  timeout          = 300  # 5 minutes — adjust if you have many resources

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.notifications.arn
    }
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.function.function_name}"
  retention_in_days = 30
}
