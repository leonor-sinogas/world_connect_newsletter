from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Newsletter API"
    database_url: str = "postgresql+psycopg://newsletter:newsletter@localhost:5432/newsletter"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()

