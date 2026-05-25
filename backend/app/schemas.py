from datetime import datetime

from pydantic import BaseModel, Field


class NewsletterCreate(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    description: str = ""


class NewsletterOut(BaseModel):
    id: int
    title: str
    description: str
    created_at: datetime

    model_config = {"from_attributes": True}


class IssueCreate(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    body: str = Field(min_length=1)


class IssueOut(BaseModel):
    id: int
    newsletter_id: int
    title: str
    body: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ReplyCreate(BaseModel):
    author_name: str = Field(min_length=1, max_length=80)
    body: str = Field(min_length=1)


class ReplyOut(BaseModel):
    id: int
    issue_id: int
    author_name: str
    body: str
    created_at: datetime

    model_config = {"from_attributes": True}

