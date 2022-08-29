## Permissions
data "aws_iam_policy_document" "lambda_assume_role_policy"{
  # TODO missing permissions for cloudwatch logs
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {  
  name = "${var.name_prefix}-lambda-role-ipset-updater"  
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "waf" {
  # Allow access to waf IP Set
  statement {
    effect = "Allow"
    actions = ["wafv2:GetIPSet","wafv2:UpdateIPSet"]
    resources = [ var.ip_set_arn ]
  }
}

resource "aws_iam_policy" "waf" {
  name   = "${var.name_prefix}-waf-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.waf.json
}

resource "aws_iam_role_policy_attachment" "lambda-policy-attachment" {
    role = aws_iam_role.lambda_role.name
    policy_arn = aws_iam_policy.waf.arn
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}


## Lambda function

data "archive_file" "python_lambda_package" {  
  type = "zip"  
  source_file = "${path.module}/code/lambda_function.py" 
  output_path = "ipset-updater.zip"
}
resource "aws_lambda_function" "ipset_updater_lambda" {
        function_name = "${var.name_prefix}-ipset-updater"
        description = "Regularly retrieves IP addresses for configured domains"
        filename      = "ipset-updater.zip"
        source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
        role          = aws_iam_role.lambda_role.arn
        runtime       = "python3.9"
        handler       = "lambda_function.lambda_handler"
        timeout       = 10

        environment {
          variables = {
            DOMAIN_NAMES = var.domain_names
            WAF_IP_SET_ID = element(split("/", var.ip_set_arn), length(split("/", var.ip_set_arn)) - 1) # the last part of the ARN is the IP Set id
            WAF_IP_SET_NAME = element(split("/", var.ip_set_arn), length(split("/", var.ip_set_arn)) - 2) # and the one before the last is the IP Set name
            LOG_LEVEL = var.log_level
          }
        }
}

## Trigger the lambda with an Eventbridge event
resource "aws_cloudwatch_event_rule" "trigger-lambda" {
  name                  = "${var.name_prefix}-run-ip-updater-function"
  description           = "Schedule IP Set updater function"
  schedule_expression   = "rate(${var.frequency} minutes)"
}

resource "aws_cloudwatch_event_target" "lambda-function-target" {
  target_id = "${var.name_prefix}-ip-updater-lambda-function-target"
  rule      = aws_cloudwatch_event_rule.trigger-lambda.name
  arn       = aws_lambda_function.ipset_updater_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.ipset_updater_lambda.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.trigger-lambda.arn
}