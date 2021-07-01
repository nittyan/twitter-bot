# DynamoDB の設定
resource aws_dynamodb_table table {
  name = "tweets"
  billing_mode = "PROVISIONED"
  read_capacity = 5
  write_capacity = 5
  hash_key = "hash"
  attribute {
    name = "hash"
    type = "S"
  }
}

resource aws_dynamodb_table_item sample {
  table_name = aws_dynamodb_table.table.name
  hash_key = aws_dynamodb_table.table.hash_key
  item = <<ITEM
  {
    "hash": {"S": "1234567"},
    "text": {"S": "サンプルツイート"},
    "weight": {"N": "1"}
  }
ITEM
}

# lambda 関数
resource "aws_lambda_function" "tweet_function" {
  function_name = "tweet"
  role = aws_iam_role.role.arn
  runtime = "python3.8"
  handler = "lambda_function.lambda_handler"
  publish = false
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  filename = data.archive_file.lambda_function.output_path

  layers = [
    "arn:aws:lambda:ap-northeast-1:770693421928:layer:Klayers-python38-tweepy:1"
  ]
}

data archive_file lambda_function {
  type = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source {
    content = data.template_file.python.rendered
    filename = "lambda_function.py"
  }
}

data template_file python {
  template = file("${path.module}/lambda_function.py")
  vars = {
    api_key = local.api_key
    api_secret_key = local.api_secret_key
    access_token = local.access_token
    access_token_secret = local.access_token_secret
  }
}

# lambda の実行権限
resource aws_iam_role role {
  name = "tweet_bot_role"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  ]
  path = "/service-role/"
  assume_role_policy = jsonencode(
  {
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
    Version = "2012-10-17"
  }
  )
}

# lambda のトリガー設定
resource aws_cloudwatch_event_rule cron {
  name = "periodic-tweet"
  schedule_expression = "cron(5 0-14 ? * * *)"
}

resource aws_cloudwatch_event_target target {
  arn = aws_lambda_function.tweet_function.arn
  rule = aws_cloudwatch_event_rule.cron.name
}

resource aws_lambda_permission cron_call_lambda_permission {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tweet_function.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.cron.arn
}