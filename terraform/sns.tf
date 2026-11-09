
resource "aws_sns_topic" "notifications" {
  name = "${var.service_name_hyphens}--notifications"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.NOTIFICATION_EMAIL
}
