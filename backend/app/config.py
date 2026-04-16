from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # OpenAI
    openai_api_key: str = ""
    openai_model: str = "gpt-5-mini"
    openai_embedding_model: str = "text-embedding-3-small"

    # ElevenLabs
    elevenlabs_api_key: str = ""
    elevenlabs_voice_id: str = "21m00Tcm4TlvDq8ikWAM"  # default: Rachel

    # AWS DynamoDB
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_region: str = "us-east-1"
    dynamodb_table_knowledge: str = "talking_head_knowledge"
    dynamodb_table_unanswered: str = "talking_head_unanswered"
    dynamodb_table_sessions: str = "talking_head_sessions"

    # FAISS
    faiss_index_path: str = "data/faiss_index"

    # App
    app_title: str = "TalkingHeadAI"
    cors_origins: list[str] = ["*"]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
