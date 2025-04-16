# AWS CloudWatch para monitoramento
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 90
  
  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-eks-cluster-logs"
    }
  )
}

# CloudWatch Log Metric Filters para alertas de segurança
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "UnauthorizedAPICalls"
  pattern        = "{ $.errorCode = \"*UnauthorizedOperation\" || $.errorCode = \"AccessDenied*\" }"
  log_group_name = aws_cloudwatch_log_group.eks_cluster.name

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "${var.environment}/SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "sign_in_without_mfa" {
  name           = "SignInWithoutMFA"
  pattern        = "{ $.eventName = \"ConsoleLogin\" && $.additionalEventData.MFAUsed = \"No\" }"
  log_group_name = aws_cloudwatch_log_group.eks_cluster.name

  metric_transformation {
    name      = "SignInWithoutMFA"
    namespace = "${var.environment}/SecurityMetrics"
    value     = "1"
  }
}

# Alarmes CloudWatch para alertas de segurança
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls_alarm" {
  alarm_name          = "${var.environment}-unauthorized-api-calls"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${var.environment}/SecurityMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors unauthorized API calls"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  ok_actions          = [aws_sns_topic.security_alerts.arn]

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-unauthorized-api-calls-alarm"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "sign_in_without_mfa_alarm" {
  alarm_name          = "${var.environment}-signin-without-mfa"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "SignInWithoutMFA"
  namespace           = "${var.environment}/SecurityMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors sign-ins without MFA"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  ok_actions          = [aws_sns_topic.security_alerts.arn]

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-signin-without-mfa-alarm"
    }
  )
}

# SNS Topic e inscrições para alertas
resource "aws_sns_topic" "security_alerts" {
  name              = "${var.environment}-security-alerts"
  kms_master_key_id = var.kms_key_logs_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-security-alerts-topic"
    }
  )
}

resource "aws_sns_topic_policy" "security_alerts" {
  arn    = aws_sns_topic.security_alerts.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid    = "AllowCloudWatchAlarms"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.security_alerts.arn]
  }
}

# Opcional: Inscrição no SNS para enviar alertas por e-mail
resource "aws_sns_topic_subscription" "security_alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Dashboards CloudWatch para visualização
resource "aws_cloudwatch_dashboard" "security" {
  dashboard_name = "${var.environment}-security-dashboard"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "${var.environment}/SecurityMetrics", "UnauthorizedAPICalls" ]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "${var.region}",
        "title": "Unauthorized API Calls"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [ "${var.environment}/SecurityMetrics", "SignInWithoutMFA" ]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "${var.region}",
        "title": "Sign-ins Without MFA"
      }
    }
  ]
}
EOF

  depends_on = [
    aws_cloudwatch_log_metric_filter.unauthorized_api_calls,
    aws_cloudwatch_log_metric_filter.sign_in_without_mfa
  ]
}

# Outputs
output "log_group_arn" {
  description = "ARN do grupo de logs do EKS"
  value       = aws_cloudwatch_log_group.eks_cluster.arn
}

output "security_alerts_topic_arn" {
  description = "ARN do tópico SNS para alertas de segurança"
  value       = aws_sns_topic.security_alerts.arn
} 