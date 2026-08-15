from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Newsletter API"
    database_url: str = "postgresql+psycopg://newsletter:newsletter@localhost:5432/newsletter"
    cors_origins: list[str] = ["http://localhost:19006", "http://127.0.0.1:19006"]
    public_base_url: str = "http://localhost:8000"
    frontend_base_url: str = "http://localhost:19006"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
