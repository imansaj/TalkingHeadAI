import boto3
from botocore.exceptions import ClientError

from app.config import get_settings

settings = get_settings()

_dynamodb = None


def get_dynamodb():
    global _dynamodb
    if _dynamodb is None:
        _dynamodb = boto3.resource(
            "dynamodb",
            region_name=settings.aws_region,
            aws_access_key_id=settings.aws_access_key_id,
            aws_secret_access_key=settings.aws_secret_access_key,
        )
    return _dynamodb


def create_tables():
    db = get_dynamodb()

    tables = [
        {
            "TableName": settings.dynamodb_table_knowledge,
            "KeySchema": [{"AttributeName": "question_id", "KeyType": "HASH"}],
            "AttributeDefinitions": [
                {"AttributeName": "question_id", "AttributeType": "S"},
            ],
            "BillingMode": "PAY_PER_REQUEST",
        },
        {
            "TableName": settings.dynamodb_table_unanswered,
            "KeySchema": [{"AttributeName": "question_id", "KeyType": "HASH"}],
            "AttributeDefinitions": [
                {"AttributeName": "question_id", "AttributeType": "S"},
            ],
            "BillingMode": "PAY_PER_REQUEST",
        },
        {
            "TableName": settings.dynamodb_table_sessions,
            "KeySchema": [{"AttributeName": "session_id", "KeyType": "HASH"}],
            "AttributeDefinitions": [
                {"AttributeName": "session_id", "AttributeType": "S"},
            ],
            "BillingMode": "PAY_PER_REQUEST",
        },
    ]

    for table_def in tables:
        try:
            db.create_table(**table_def)
        except ClientError as e:
            if e.response["Error"]["Code"] != "ResourceInUseException":
                raise


def get_table(name: str):
    return get_dynamodb().Table(name)
