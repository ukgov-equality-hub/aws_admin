
resource "aws_iam_role" "lambda_role" {
  name = "${var.service_name_hyphens}--lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.service_name_hyphens}--lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "logs:CreateLogStream"
        Resource = aws_cloudwatch_log_group.lambda_logs.arn
      },
      {
        Effect = "Allow"
        Action = "logs:PutLogEvents"
        Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:log-stream:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVpcs",
          "ec2:DescribeAddresses"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = [
          "arn:aws:ec2:${var.aws_region}:*:network-interface/*",
          "arn:aws:ec2:${var.aws_region}:*:elastic-ip/*"
        ]
        Condition = {
          "ForAllValues:StringEquals" = {
            "aws:TagKeys" = ["Service", "Environment"]
          }
        }
      },
      {
        # SNS publish for notifications
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.notifications.arn
      }
    ]
  })
}
