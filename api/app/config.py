import os
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    app_name: str = "Fargate API"
    environment: str = Field(default="development", alias="ENVIRONMENT")
    port: int = Field(default=8000, alias="PORT")
    
    # Database Settings
    db_user: str = Field(default="postgres", alias="DB_USER")
    db_password: str = Field(default="postgres", alias="DB_PASSWORD")
    db_host: str = Field(default="localhost", alias="DB_HOST")
    db_port: int = Field(default=5432, alias="DB_PORT")
    db_name: str = Field(default="app_db", alias="DB_NAME")
    database_url: str | None = Field(default=None, alias="DATABASE_URL")

    # Retry settings for database connection
    db_connect_retries: int = Field(default=10, alias="DB_CONNECT_RETRIES")
    db_retry_delay: float = Field(default=2.0, alias="DB_RETRY_DELAY")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    def get_database_url(self) -> str:
        if self.database_url:
            # Handle postgres:// to postgresql:// for SQLAlchemy compatibility if needed
            if self.database_url.startswith("postgres://"):
                return self.database_url.replace("postgres://", "postgresql://", 1)
            return self.database_url
        return f"postgresql://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"


settings = Settings()
