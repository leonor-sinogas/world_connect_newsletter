from fastapi import Depends, FastAPI, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.database import Base, engine, get_db
from app.models import Issue, Newsletter, Reply
from app.schemas import (
    IssueCreate,
    IssueOut,
    NewsletterCreate,
    NewsletterOut,
    ReplyCreate,
    ReplyOut,
)

Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.app_name)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/newsletters", response_model=NewsletterOut, status_code=status.HTTP_201_CREATED)
def create_newsletter(payload: NewsletterCreate, db: Session = Depends(get_db)):
    newsletter = Newsletter(title=payload.title, description=payload.description)
    db.add(newsletter)
    db.commit()
    db.refresh(newsletter)
    return newsletter


@app.get("/newsletters", response_model=list[NewsletterOut])
def list_newsletters(db: Session = Depends(get_db)):
    return db.scalars(select(Newsletter).order_by(Newsletter.created_at.desc())).all()


@app.post("/newsletters/{newsletter_id}/issues", response_model=IssueOut, status_code=status.HTTP_201_CREATED)
def create_issue(newsletter_id: int, payload: IssueCreate, db: Session = Depends(get_db)):
    newsletter = db.get(Newsletter, newsletter_id)
    if newsletter is None:
        raise HTTPException(status_code=404, detail="Newsletter not found")

    issue = Issue(newsletter_id=newsletter_id, title=payload.title, body=payload.body)
    db.add(issue)
    db.commit()
    db.refresh(issue)
    return issue


@app.get("/newsletters/{newsletter_id}/issues", response_model=list[IssueOut])
def list_issues(newsletter_id: int, db: Session = Depends(get_db)):
    newsletter = db.get(Newsletter, newsletter_id)
    if newsletter is None:
        raise HTTPException(status_code=404, detail="Newsletter not found")

    query = select(Issue).where(Issue.newsletter_id == newsletter_id).order_by(Issue.created_at.desc())
    return db.scalars(query).all()


@app.post("/issues/{issue_id}/replies", response_model=ReplyOut, status_code=status.HTTP_201_CREATED)
def create_reply(issue_id: int, payload: ReplyCreate, db: Session = Depends(get_db)):
    issue = db.get(Issue, issue_id)
    if issue is None:
        raise HTTPException(status_code=404, detail="Issue not found")

    reply = Reply(issue_id=issue_id, author_name=payload.author_name, body=payload.body)
    db.add(reply)
    db.commit()
    db.refresh(reply)
    return reply


@app.get("/issues/{issue_id}/replies", response_model=list[ReplyOut])
def list_replies(issue_id: int, db: Session = Depends(get_db)):
    issue = db.get(Issue, issue_id)
    if issue is None:
        raise HTTPException(status_code=404, detail="Issue not found")

    query = select(Reply).where(Reply.issue_id == issue_id).order_by(Reply.created_at.asc())
    return db.scalars(query).all()

