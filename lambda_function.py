import json
import random
import boto3
import tweepy


def lambda_handler(event, context):
    text = random_choice_text()
    tweet(text)

    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }


def tweet(text: str):
    auth = tweepy.OAuthHandler('${api_key}', '${api_secret_key}')
    auth.set_access_token('${access_token}',
                          '${access_token_secret}')
    api = tweepy.API(auth)
    api.update_status(text)


def random_choice_text() -> str:
    db = boto3.resource('dynamodb')
    table = db.Table('tweets')
    res = table.scan()
    items = res['Items']

    texts = []
    weights = []
    for item in items:
        texts.append(item['text'])
        weights.append(int(item['weight']))
    random.seed()
    return random.choices(texts, k=1, weights=weights)[0]
