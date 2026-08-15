import hashlib
import secrets
from io import BytesIO
from pathlib import Path
from urllib.parse import urlsplit
from uuid import uuid4

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from sqlalchemy import or_, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from pwdlib import PasswordHash
from PIL import Image, UnidentifiedImageError

from app.config import settings
from app.database import Base, engine, get_db
from app.models import (
    AuthSession,
    FriendRequest,
    Issue,
    IssueImage,
    Newsletter,
    NewsletterInvitation,
    NewsletterJoinRequest,
    PasswordResetCode,
    Reply,
    Subscription,
    User,
)
from app.schemas import (
    AuthOut,
    FriendRequestAction,
    FriendRequestCreate,
    FriendRequestOut,
    FriendsOut,
    IssueCreate,
    IssueOut,
    FeedOut,
    NewsletterCreate,
    NewsletterInvitationOut,
    NewsletterInviteCreate,
    NewsletterTransfer,
    NewsletterOut,
    NewsletterShareLinkOut,
    PasswordResetComplete,
    PasswordResetRequest,
    PasswordResetVerify,
    ProfileUpdate,
    ReplyCreate,
    ReplyOut,
    UserCreate,
    UserLogin,
    UserOut,
    SharedNewsletterOut,
)


password_hasher = PasswordHash.recommended()
bearer_scheme = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(password: str, encoded: str) -> bool:
    try:
        return password_hasher.verify(password, encoded)
    except Exception:
        # Existing development rows used an unsalted SHA-256 digest. Accept them
        # once so login can transparently upgrade the stored hash to Argon2id.
        return secrets.compare_digest(encoded, hashlib.sha256(password.encode("utf-8")).hexdigest())


def digest_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_session(user: User, db: Session) -> AuthOut:
    token = secrets.token_urlsafe(32)
    db.add(AuthSession(user_id=user.id, token_hash=digest_token(token)))
    db.commit()
    return AuthOut(access_token=token, user=user)


def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Authentication required", headers={"WWW-Authenticate": "Bearer"})
    session = db.scalar(select(AuthSession).where(AuthSession.token_hash == digest_token(credentials.credentials)))
    user = db.get(User, session.user_id) if session else None
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid access token", headers={"WWW-Authenticate": "Bearer"})
    return user


def require_identity(user_id: int, user: User) -> None:
    if user_id != user.id:
        raise HTTPException(status_code=403, detail="You cannot act as another user")


UPLOAD_DIR = Path(__file__).resolve().parent.parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)
ALLOWED_IMAGE_TYPES = {"image/jpeg": ".jpg", "image/png": ".png"}
ALLOWED_IMAGE_EXTENSIONS = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png"}
MAX_IMAGE_SIZE = 5 * 1024 * 1024
MAX_IMAGE_PIXELS = 25_000_000


def detect_image_type(contents: bytes) -> str | None:
    """Identify and decode supported images from their contents."""
    signature_type = None
    if contents.startswith(b"\x89PNG\r\n\x1a\n"):
        signature_type = "image/png"
    elif contents.startswith(b"\xff\xd8\xff"):
        signature_type = "image/jpeg"
    if signature_type is None:
        return None
    try:
        with Image.open(BytesIO(contents)) as image:
            decoded_type = Image.MIME.get(image.format or "")
            if image.width * image.height > MAX_IMAGE_PIXELS:
                return None
            image.verify()
    except (Image.DecompressionBombError, UnidentifiedImageError, OSError, SyntaxError, ValueError):
        return None
    return signature_type if decoded_type == signature_type else None


def normalize_image_urls(image_urls: list[str], legacy_photo_url: str = "") -> list[str]:
    """Normalize and validate image references accepted from the client.

    Images must either be served by our upload route or use an HTTP(S) URL. In
    particular this prevents active schemes such as javascript: from being
    persisted and later rendered by a client.
    """
    candidates = [*image_urls]
    if legacy_photo_url.strip():
        candidates.insert(0, legacy_photo_url)

    normalized: list[str] = []
    for candidate in candidates:
        url = candidate.strip()
        if not url or url in normalized:
            continue
        if len(url) > 2048 or any(character in url for character in ("\r", "\n", "\x00")):
            raise HTTPException(status_code=422, detail="Invalid image URL")
        parsed = urlsplit(url)
        is_local_upload = url.startswith("/uploads/") and not url.startswith("//")
        is_remote_image = parsed.scheme in {"http", "https"} and bool(parsed.netloc)
        if not (is_local_upload or is_remote_image):
            raise HTTPException(status_code=422, detail="Images must use HTTP(S) or a local upload URL")
        normalized.append(url)

    if len(normalized) > 10:
        raise HTTPException(status_code=422, detail="Use at most 10 images")
    return normalized


def migrate_sqlite_schema() -> None:
    if not settings.database_url.startswith("sqlite"):
        return

    required_columns = {
        "newsletters": {
            "owner_id": "INTEGER",
            "visibility": "TEXT DEFAULT 'public' NOT NULL",
            "category": "TEXT DEFAULT 'friends' NOT NULL",
            "image_url": "TEXT DEFAULT '' NOT NULL",
            "share_token_hash": "TEXT",
        },
        "users": {
            "email": "TEXT DEFAULT '' NOT NULL",
            "time_zone": "TEXT DEFAULT 'GMT' NOT NULL",
            "appearance": "TEXT DEFAULT 'system' NOT NULL",
        },
        "issues": {
            "author_id": "INTEGER",
            "photo_url": "TEXT DEFAULT '' NOT NULL",
        },
        "replies": {
            "author_id": "INTEGER",
            "image_url": "TEXT DEFAULT '' NOT NULL",
        },
        "newsletter_join_requests": {
            "newsletter_id": "INTEGER NOT NULL",
            "requester_id": "INTEGER NOT NULL",
            "status": "TEXT DEFAULT 'pending' NOT NULL",
            "created_at": "DATETIME",
        },
    }

    with engine.begin() as conn:
        for table, columns in required_columns.items():
            existing = {row[1] for row in conn.execute(text(f"PRAGMA table_info({table})"))}
            for column, definition in columns.items():
                if column not in existing:
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {definition}"))
        users = conn.execute(text("SELECT id, username, email FROM users WHERE email = ''")).fetchall()
        for user_id, username, _ in users:
            conn.execute(
                text("UPDATE users SET email = :email WHERE id = :id"),
                {"email": f"{username}@local.dev", "id": user_id},
            )


Base.metadata.create_all(bind=engine)
migrate_sqlite_schema()

app = FastAPI(title=settings.app_name)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/uploads")
async def upload_image(file: UploadFile = File(...), _: User = Depends(current_user)):
    contents = await file.read(MAX_IMAGE_SIZE + 1)
    await file.close()
    if len(contents) > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=400, detail="Images must be 5 MB or smaller")

    detected_type = detect_image_type(contents)
    if detected_type is None:
        raise HTTPException(status_code=400, detail="Only valid JPG and PNG uploads are allowed")

    # Flutter web may omit a useful MIME type. Accept that case, but reject an
    # explicit type or extension that contradicts the actual bytes.
    declared_type = (file.content_type or "").lower().split(";", 1)[0].strip()
    if declared_type not in {"", "application/octet-stream", detected_type}:
        raise HTTPException(status_code=400, detail="File contents do not match the declared image type")
    supplied_extension = Path(file.filename or "").suffix.lower()
    if supplied_extension and ALLOWED_IMAGE_EXTENSIONS.get(supplied_extension) != detected_type:
        raise HTTPException(status_code=400, detail="File must use a .png, .jpg, or .jpeg extension matching its contents")

    extension = ALLOWED_IMAGE_TYPES[detected_type]
    filename = f"{uuid4().hex}{extension}"
    destination = UPLOAD_DIR / filename
    destination.write_bytes(contents)
    return {"url": f"{settings.public_base_url.rstrip('/')}/uploads/{filename}"}


@app.post("/auth/signup", response_model=AuthOut, status_code=status.HTTP_201_CREATED)
def signup(payload: UserCreate, db: Session = Depends(get_db)):
    user = User(
        username=payload.username.strip(),
        email=payload.email.strip().lower(),
        password_hash=hash_password(payload.password),
        time_zone=payload.time_zone.strip() or "GMT",
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Username is already taken") from exc
    db.refresh(user)
    return issue_session(user, db)


@app.post("/auth/login", response_model=AuthOut)
def login(payload: UserLogin, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.username == payload.username.strip()))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    if not user.password_hash.startswith("$argon2"):
        user.password_hash = hash_password(payload.password)
        db.commit()
    return issue_session(user, db)


@app.post("/auth/recover-password")
def recover_password(payload: PasswordResetRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email.strip().lower()))
    if user is None:
        return {"status": "sent"}
    code = f"{secrets.randbelow(1_000_000):06d}"
    db.add(PasswordResetCode(user_id=user.id, code=code))
    db.commit()
    print(f"[dev email] Password reset code for {user.email}: {code}")
    return {"status": "sent"}


@app.post("/auth/verify-reset-code")
def verify_reset_code(payload: PasswordResetVerify, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email.strip().lower()))
    if user is None or latest_reset_code(user.id, db) != payload.code:
        raise HTTPException(status_code=400, detail="Invalid reset code")
    return {"status": "verified"}


@app.post("/auth/reset-password")
def reset_password(payload: PasswordResetComplete, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email.strip().lower()))
    reset = latest_reset(user.id, db) if user else None
    if user is None or reset is None or reset.code != payload.code or reset.status != "pending":
        raise HTTPException(status_code=400, detail="Invalid reset code")
    user.password_hash = hash_password(payload.password)
    reset.status = "used"
    db.commit()
    return {"status": "password_reset"}


def latest_reset(user_id: int, db: Session) -> PasswordResetCode | None:
    return db.scalar(
        select(PasswordResetCode)
        .where(PasswordResetCode.user_id == user_id)
        .order_by(PasswordResetCode.created_at.desc(), PasswordResetCode.id.desc())
    )


def latest_reset_code(user_id: int, db: Session) -> str | None:
    reset = latest_reset(user_id, db)
    if reset is None or reset.status != "pending":
        return None
    return reset.code


@app.get("/users/{user_id}", response_model=UserOut)
def get_user(user_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    require_identity(user_id, user)
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@app.patch("/users/{user_id}", response_model=UserOut)
def update_profile(user_id: int, payload: ProfileUpdate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    require_identity(user_id, user)
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    user.profile_photo_url = payload.profile_photo_url.strip()
    user.time_zone = payload.time_zone.strip() or "GMT"
    user.appearance = payload.appearance
    db.commit()
    db.refresh(user)
    return user


def user_has_invitation(newsletter_id: int, user_id: int, db: Session) -> bool:
    return db.scalar(
        select(NewsletterInvitation).where(
            NewsletterInvitation.newsletter_id == newsletter_id,
            NewsletterInvitation.invitee_id == user_id,
        )
    ) is not None


def users_are_friends(user_id: int, other_user_id: int, db: Session) -> bool:
    return db.scalar(
        select(FriendRequest).where(
            FriendRequest.status == "accepted",
            or_(
                (FriendRequest.requester_id == user_id) & (FriendRequest.addressee_id == other_user_id),
                (FriendRequest.requester_id == other_user_id) & (FriendRequest.addressee_id == user_id),
            ),
        )
    ) is not None


def can_access_newsletter(newsletter: Newsletter, user_id: int, db: Session) -> bool:
    if newsletter.visibility == "public" or newsletter.owner_id == user_id:
        return True
    if user_has_invitation(newsletter.id, user_id, db):
        return True
    return db.scalar(
        select(Subscription.id).where(
            Subscription.newsletter_id == newsletter.id,
            Subscription.user_id == user_id,
        )
    ) is not None


def new_share_token(newsletter: Newsletter) -> str:
    token = secrets.token_urlsafe(32)
    newsletter.share_token_hash = digest_token(token)
    return token


def share_url(token: str) -> str:
    return f"{settings.frontend_base_url.rstrip('/')}/#/newsletter/shared/{token}"


def newsletter_out(newsletter: Newsletter, subscribed_ids: set[int], user_id: int | None = None, db: Session | None = None, raw_share_token: str | None = None) -> NewsletterOut:
    is_owner = user_id is not None and newsletter.owner_id == user_id
    is_subscribed = newsletter.id in subscribed_ids
    invited = bool(user_id and db and user_has_invitation(newsletter.id, user_id, db))
    request = db.scalar(select(NewsletterJoinRequest).where(NewsletterJoinRequest.newsletter_id == newsletter.id, NewsletterJoinRequest.requester_id == user_id)) if user_id and db else None
    return NewsletterOut(
        id=newsletter.id,
        owner_id=newsletter.owner_id,
        title=newsletter.title,
        description=newsletter.description,
        visibility=newsletter.visibility,
        category=newsletter.category,
        image_url=newsletter.image_url,
        created_at=newsletter.created_at,
        is_subscribed=is_subscribed,
        can_invite=newsletter.visibility == "public" or is_owner,
        can_join=(newsletter.visibility == "public" or is_owner or invited) and not is_subscribed,
        join_status=("accepted" if is_subscribed else request.status if request else None),
        share_url=share_url(raw_share_token) if raw_share_token else None,
    )


@app.post("/newsletters", response_model=NewsletterOut, status_code=status.HTTP_201_CREATED)
def create_newsletter(payload: NewsletterCreate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    if payload.owner_id is not None:
        require_identity(payload.owner_id, user)
    if payload.owner_id is not None and db.get(User, payload.owner_id) is None:
        raise HTTPException(status_code=404, detail="Owner not found")

    owner_id = payload.owner_id if payload.owner_id is not None else user.id
    invitee_ids = set(payload.invitee_ids)
    if user.id in invitee_ids:
        raise HTTPException(status_code=400, detail="You cannot invite yourself")
    invitees = {candidate.id: candidate for candidate in db.scalars(select(User).where(User.id.in_(invitee_ids))).all()}
    if len(invitees) != len(invitee_ids):
        raise HTTPException(status_code=404, detail="One or more invitees were not found")
    if any(not users_are_friends(user.id, invitee_id, db) for invitee_id in invitee_ids):
        raise HTTPException(status_code=403, detail="You can only invite friends to newsletters")

    newsletter = Newsletter(
        owner_id=owner_id,
        title=payload.title.strip(),
        description=payload.description.strip(),
        visibility=payload.visibility,
        category=payload.category.strip(),
        image_url=payload.image_url.strip(),
    )
    token = new_share_token(newsletter)
    db.add(newsletter)
    db.flush()
    db.add(Subscription(user_id=owner_id, newsletter_id=newsletter.id))
    for invitee_id in invitee_ids:
        db.add(NewsletterInvitation(newsletter_id=newsletter.id, inviter_id=user.id, invitee_id=invitee_id))
    db.commit()
    db.refresh(newsletter)
    return newsletter_out(newsletter, {newsletter.id}, user.id, db, token)


@app.get("/newsletters", response_model=list[NewsletterOut])
def list_newsletters(user_id: int | None = None, user: User = Depends(current_user), db: Session = Depends(get_db)):
    if user_id is not None:
        require_identity(user_id, user)
    subscribed_ids: set[int] = set()
    if user_id is not None:
        subscribed_ids = set(
            db.scalars(select(Subscription.newsletter_id).where(Subscription.user_id == user_id)).all()
        )
    # The newsletter directory includes private newsletters as discoverable
    # metadata; their issues remain access-controlled until the owner approves
    # a join request.
    newsletters = db.scalars(select(Newsletter).order_by(Newsletter.created_at.desc())).all()
    return [newsletter_out(newsletter, subscribed_ids, user_id, db) for newsletter in newsletters]


@app.post("/newsletters/{newsletter_id}/share-link", response_model=NewsletterShareLinkOut)
def rotate_newsletter_share_link(newsletter_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    newsletter = db.get(Newsletter, newsletter_id)
    if newsletter is None:
        raise HTTPException(status_code=404, detail="Newsletter not found")
    if not can_access_newsletter(newsletter, user.id, db):
        raise HTTPException(status_code=403, detail="Subscribe to this newsletter before sharing it")
    token = new_share_token(newsletter)
    db.commit()
    return NewsletterShareLinkOut(share_url=share_url(token))


@app.get("/shared/newsletters/{token}", response_model=SharedNewsletterOut)
def shared_newsletter(token: str, db: Session = Depends(get_db)):
    if len(token) < 32 or len(token) > 128:
        raise HTTPException(status_code=404, detail="Shared newsletter not found")
    newsletter = db.scalar(select(Newsletter).where(Newsletter.share_token_hash == digest_token(token)))
    if newsletter is None:
        raise HTTPException(status_code=404, detail="Shared newsletter not found")
    owner = db.get(User, newsletter.owner_id) if newsletter.owner_id else None
    return SharedNewsletterOut(
        id=newsletter.id,
        title=newsletter.title,
        description=newsletter.description,
        image_url=newsletter.image_url,
        category=newsletter.category,
        owner_username=owner.username if owner else "",
    )


@app.get("/users/{user_id}/subscriptions", response_model=list[NewsletterOut])
def list_subscriptions(user_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    require_identity(user_id, user)
    if db.get(User, user_id) is None:
        raise HTTPException(status_code=404, detail="User not found")
    query = (
        select(Newsletter)
        .join(Subscription, Subscription.newsletter_id == Newsletter.id)
        .where(Subscription.user_id == user_id)
        .order_by(Newsletter.created_at.desc())
    )
    newsletters = db.scalars(query).all()
    return [newsletter_out(newsletter, {newsletter.id for newsletter in newsletters}, user_id, db) for newsletter in newsletters]


@app.post("/newsletters/{newsletter_id}/subscribe", status_code=status.HTTP_201_CREATED)
def subscribe(newsletter_id: int, user_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    require_identity(user_id, user)
    if db.get(User, user_id) is None:
        raise HTTPException(status_code=404, detail="User not found")
    newsletter = db.get(Newsletter, newsletter_id)
    if newsletter is None:
        raise HTTPException(status_code=404, detail="Newsletter not found")
    if newsletter.visibility == "private" and newsletter.owner_id != user_id and not user_has_invitation(newsletter_id, user_id, db):
        raise HTTPException(status_code=403, detail="Private newsletters require an invitation")
    db.add(Subscription(user_id=user_id, newsletter_id=newsletter_id))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
    return {"status": "subscribed"}


@app.post("/newsletters/{newsletter_id}/join-request")
def request_newsletter_join(newsletter_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    newsletter = db.get(Newsletter, newsletter_id)
    if newsletter is None:
        raise HTTPException(status_code=404, detail="Newsletter not found")
    if newsletter.visibility != "private":
        return subscribe(newsletter_id, user.id, user, db)
    if newsletter.owner_id == user.id:
        return {"status": "accepted"}
    existing = db.scalar(select(Subscription).where(Subscription.newsletter_id == newsletter_id, Subscription.user_id == user.id))
    if existing:
        return {"status": "accepted"}
    request = db.scalar(select(NewsletterJoinRequest).where(NewsletterJoinRequest.newsletter_id == newsletter_id, NewsletterJoinRequest.requester_id == user.id))
    if request is None:
        request = NewsletterJoinRequest(newsletter_id=newsletter_id, requester_id=user.id)
        db.add(request)
    elif request.status == "denied":
        request.status = "pending"
    db.commit()
    return {"status": request.status}


@app.get("/newsletters/{newsletter_id}/join-requests")
def list_newsletter_join_requests(newsletter_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    newsletter = db.get(Newsletter, newsletter_id)
    if newsletter is None:
        raise HTTPException(status_code=404, detail="Newsletter not found")
    if newsletter.owner_id != user.id:
        raise HTTPException(status_code=403, detail="Only the owner can review join requests")
    rows = db.scalars(select(NewsletterJoinRequest).where(NewsletterJoinRequest.newsletter_id == newsletter_id, NewsletterJoinRequest.status == "pending")).all()
    requesters = {candidate.id: candidate for candidate in db.scalars(select(User).where(User.id.in_([row.requester_id for row in rows]))).all()}
    return [{"id": row.id, "newsletter_id": row.newsletter_id, "requester_id": row.requester_id, "requester_username": requesters[row.requester_id].username if row.requester_id in requesters else "User", "requester_photo_url": requesters[row.requester_id].profile_photo_url if row.requester_id in requesters else "", "status": row.status} for row in rows]


@app.patch("/newsletters/{newsletter_id}/join-requests/{request_id}")
def review_newsletter_join_request(newsletter_id: int, request_id: int, action: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    newsletter = db.get(Newsletter, newsletter_id)
    request = db.get(NewsletterJoinRequest, request_id)
    if newsletter is None or request is None or request.newsletter_id != newsletter_id:
        raise HTTPException(status_code=404, detail="Join request not found")
    if newsletter.owner_id != user.id:
        raise HTTPException(status_code=403, detail="Only the owner can review join requests")
    if action not in {"approve", "deny"}:
        raise HTTPException(status_code=400, detail="Action must be approve or deny")
    request.status = "accepted" if action == "approve" else "denied"
    if action == "approve":
        db.add(Subscription(user_id=request.requester_id, newsletter_id=newsletter_id))
    db.commit()
    return {"status": request.status}


def invitation_out(invitation: NewsletterInvitation, users: dict[int, User]) -> NewsletterInvitationOut:
    inviter = users[invitation.inviter_id]
    invitee = users[invitation.invitee_id]
    return NewsletterInvitationOut(
        id=invitation.id,
        newsletter_id=invitation.newsletter_id,
        inviter_id=invitation.inviter_id,
        inviter_username=inviter.username,
        invitee_id=invitation.invitee_id,
        invitee_username=invitee.username,
        created_at=invitation.created_at,
    )


@app.post("/newsletters/{newsletter_id}/invitations", response_model=NewsletterInvitationOut, status_code=status.HTTP_201_CREATED)
def invite_to_newsletter(newsletter_id: int, payload: NewsletterInviteCreate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    require_identity(payload.inviter_id, user)
    newsletter = db.get(Newsletter, newsletter_id)
    inviter = db.get(User, payload.inviter_id)
    invitee = db.get(User, payload.invitee_id)
    if newsletter is None:
        raise HTTPException(status_code=404, detail="Newsletter not found")
    if inviter is None or invitee is None:
        raise HTTPException(status_code=404, detail="User not found")
    if not users_are_friends(payload.inviter_id, payload.invitee_id, db):
        raise HTTPException(status_code=403, detail="You can only invite friends to newsletters")
    if not can_access_newsletter(newsletter, payload.inviter_id, db):
        raise HTTPException(status_code=403, detail="Join this newsletter before inviting friends")

    invitation = NewsletterInvitation(
        newsletter_id=newsletter_id,
        inviter_id=payload.inviter_id,
        invitee_id=payload.invitee_id,
    )
    db.add(invitation)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        invitation = db.scalar(
            select(NewsletterInvitation).where(
                NewsletterInvitation.newsletter_id == newsletter_id,
                NewsletterInvitation.invitee_id == payload.invitee_id,
            )
        )
    db.refresh(invitation)
    return invitation_out(invitation, {inviter.id: inviter, invitee.id: invitee})


@app.delete("/newsletters/{newsletter_id}/subscribe")
def unsubscribe(newsletter_id: int, user_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    require_identity(user_id, user)
    newsletter = db.get(Newsletter, newsletter_id)
    if newsletter is not None and newsletter.owner_id == user_id:
        raise HTTPException(status_code=409, detail="Transfer newsletter ownership before leaving")
    subscription = db.scalar(
        select(Subscription).where(
            Subscription.user_id == user_id,
            Subscription.newsletter_id == newsletter_id,
        )
    )
    if subscription is not None:
        db.delete(subscription)
        db.commit()
    return {"status": "unsubscribed"}


@app.post("/newsletters/{newsletter_id}/transfer")
def transfer_newsletter(newsletter_id: int, payload: NewsletterTransfer, user: User = Depends(current_user), db: Session = Depends(get_db)):
    newsletter = db.get(Newsletter, newsletter_id)
    new_owner = db.get(User, payload.new_owner_id)
    if newsletter is None or new_owner is None:
        raise HTTPException(status_code=404, detail="Newsletter or user not found")
    if newsletter.owner_id != user.id:
        raise HTTPException(status_code=403, detail="Only the owner can transfer this newsletter")
    if payload.new_owner_id == user.id:
        raise HTTPException(status_code=400, detail="Choose a different owner")
    newsletter.owner_id = new_owner.id
    if db.scalar(select(Subscription.id).where(Subscription.user_id == new_owner.id, Subscription.newsletter_id == newsletter_id)) is None:
        db.add(Subscription(user_id=new_owner.id, newsletter_id=newsletter_id))
    db.commit()
    return {"status": "transferred", "owner_id": new_owner.id}


@app.post("/newsletters/{newsletter_id}/issues", response_model=IssueOut, status_code=status.HTTP_201_CREATED)
def create_issue(newsletter_id: int, payload: IssueCreate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    require_identity(payload.author_id, user)
    newsletter = db.get(Newsletter, newsletter_id)
    user = db.get(User, payload.author_id)
    if newsletter is None:
        raise HTTPException(status_code=404, detail="Newsletter not found")
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    subscription = db.scalar(
        select(Subscription.id).where(
            Subscription.user_id == user.id,
            Subscription.newsletter_id == newsletter_id,
        )
    )
    if newsletter.owner_id != user.id and subscription is None:
        raise HTTPException(status_code=403, detail="Subscribe to this newsletter before posting")

    title = payload.title.strip()
    body = payload.body.strip()
    if not title or not body:
        raise HTTPException(status_code=422, detail="Title and text cannot be blank")
    if len(body.split()) > 300:
        raise HTTPException(status_code=422, detail="Issues must be 300 words or fewer")

    image_urls = normalize_image_urls(payload.image_urls, payload.photo_url)

    issue = Issue(
        newsletter_id=newsletter_id,
        author_id=payload.author_id,
        title=title,
        body=body,
        photo_url=image_urls[0] if image_urls else "",
    )
    issue.images = [IssueImage(url=url, position=position) for position, url in enumerate(image_urls)]
    db.add(issue)
    try:
        db.commit()
        db.refresh(issue)
    except Exception:
        db.rollback()
        raise
    return issue_out(issue, newsletter, user)


def reply_out(reply: Reply, authors: dict[int, User] | None = None) -> ReplyOut:
    author = authors.get(reply.author_id) if authors and reply.author_id is not None else None
    return ReplyOut(
        id=reply.id,
        issue_id=reply.issue_id,
        author_id=reply.author_id,
        author_name=reply.author_name,
        author_photo_url=author.profile_photo_url if author else "",
        body=reply.body,
        image_url=reply.image_url,
        created_at=reply.created_at,
    )


def issue_out(
    issue: Issue,
    newsletter: Newsletter,
    author: User | None,
    replies: list[Reply] | None = None,
    reply_authors: dict[int, User] | None = None,
) -> IssueOut:
    return IssueOut(
        id=issue.id,
        newsletter_id=issue.newsletter_id,
        author_id=issue.author_id,
        title=issue.title,
        body=issue.body,
        photo_url=issue.photo_url,
        image_urls=[image.url for image in issue.images] or ([issue.photo_url] if issue.photo_url else []),
        created_at=issue.created_at,
        newsletter_title=newsletter.title,
        author_name=author.username if author else "Unknown",
        replies=[reply_out(reply, reply_authors) for reply in replies or []],
    )


def authors_for_replies(replies_by_issue: dict[int, list[Reply]], db: Session) -> dict[int, User]:
    author_ids = {
        reply.author_id
        for replies in replies_by_issue.values()
        for reply in replies
        if reply.author_id is not None
    }
    return (
        {author.id: author for author in db.scalars(select(User).where(User.id.in_(author_ids))).all()}
        if author_ids
        else {}
    )


@app.get("/newsletters/{newsletter_id}/issues", response_model=list[IssueOut])
def list_issues(newsletter_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    newsletter = db.get(Newsletter, newsletter_id)
    if newsletter is None:
        raise HTTPException(status_code=404, detail="Newsletter not found")
    if not can_access_newsletter(newsletter, user.id, db):
        raise HTTPException(status_code=403, detail="You cannot access this newsletter")

    query = select(Issue).where(Issue.newsletter_id == newsletter_id).order_by(Issue.created_at.desc())
    issues = db.scalars(query).all()
    users = {user.id: user for user in db.scalars(select(User)).all()}
    replies_by_issue = replies_for_issues([issue.id for issue in issues], db)
    reply_authors = authors_for_replies(replies_by_issue, db)
    return [
        issue_out(issue, newsletter, users.get(issue.author_id), replies_by_issue.get(issue.id, []), reply_authors)
        for issue in issues
    ]


def replies_for_issues(issue_ids: list[int], db: Session) -> dict[int, list[Reply]]:
    if not issue_ids:
        return {}
    replies = db.scalars(
        select(Reply).where(Reply.issue_id.in_(issue_ids)).order_by(Reply.created_at.asc())
    ).all()
    replies_by_issue: dict[int, list[Reply]] = {issue_id: [] for issue_id in issue_ids}
    for reply in replies:
        replies_by_issue.setdefault(reply.issue_id, []).append(reply)
    return replies_by_issue


@app.get("/users/{user_id}/feed", response_model=FeedOut)
def feed(
    user_id: int,
    limit: int = 5,
    offset: int = 0,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
):
    require_identity(user_id, user)
    if limit < 1 or limit > 50:
        raise HTTPException(status_code=422, detail="limit must be between 1 and 50")
    if offset < 0 or offset > 100000:
        raise HTTPException(status_code=422, detail="offset must be between 0 and 100000")
    if db.get(User, user_id) is None:
        raise HTTPException(status_code=404, detail="User not found")

    query = (
        select(Issue, Newsletter, User)
        .join(Newsletter, Newsletter.id == Issue.newsletter_id)
        .join(Subscription, Subscription.newsletter_id == Newsletter.id)
        .outerjoin(User, User.id == Issue.author_id)
        .where(Subscription.user_id == user_id)
        .order_by(Issue.created_at.desc(), Issue.id.desc())
        .offset(offset)
        .limit(limit + 1)
    )
    rows = db.execute(query).all()
    has_more = len(rows) > limit
    rows = rows[:limit]
    replies_by_issue = replies_for_issues([issue.id for issue, _, _ in rows], db)
    reply_authors = authors_for_replies(replies_by_issue, db)
    items = [
        issue_out(issue, newsletter, author, replies_by_issue.get(issue.id, []), reply_authors)
        for issue, newsletter, author in rows
    ]
    return FeedOut(items=items, limit=limit, offset=offset, has_more=has_more)


@app.post("/issues/{issue_id}/replies", response_model=ReplyOut, status_code=status.HTTP_201_CREATED)
def create_reply(issue_id: int, payload: ReplyCreate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    require_identity(payload.author_id, user)
    issue = db.get(Issue, issue_id)
    user = db.get(User, payload.author_id)
    if issue is None:
        raise HTTPException(status_code=404, detail="Issue not found")
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    newsletter = db.get(Newsletter, issue.newsletter_id)
    if newsletter is None or not can_access_newsletter(newsletter, user.id, db):
        raise HTTPException(status_code=403, detail="You cannot access this newsletter")

    body = payload.body.strip()
    image_urls = normalize_image_urls([], payload.image_url)
    image_url = image_urls[0] if image_urls else ""
    if not body and not image_url:
        raise HTTPException(status_code=422, detail="Add reply text or an image")
    if len(body.split()) > 300:
        raise HTTPException(status_code=422, detail="Replies must be 300 words or fewer")

    reply = Reply(
        issue_id=issue_id,
        author_id=user.id,
        author_name=user.username,
        body=body,
        image_url=image_url,
    )
    db.add(reply)
    db.commit()
    db.refresh(reply)
    return reply_out(reply, {user.id: user})


@app.get("/issues/{issue_id}/replies", response_model=list[ReplyOut])
def list_replies(issue_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    issue = db.get(Issue, issue_id)
    if issue is None:
        raise HTTPException(status_code=404, detail="Issue not found")
    newsletter = db.get(Newsletter, issue.newsletter_id)
    if newsletter is None or not can_access_newsletter(newsletter, user.id, db):
        raise HTTPException(status_code=403, detail="You cannot access this newsletter")

    query = select(Reply).where(Reply.issue_id == issue_id).order_by(Reply.created_at.asc())
    replies = db.scalars(query).all()
    authors = {author.id: author for author in db.scalars(select(User).where(User.id.in_({r.author_id for r in replies if r.author_id is not None}))).all()} if replies else {}
    return [reply_out(reply, authors) for reply in replies]


@app.delete("/issues/{issue_id}")
def delete_issue(issue_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    issue = db.get(Issue, issue_id)
    if issue is None:
        raise HTTPException(status_code=404, detail="Issue not found")
    if issue.author_id != user.id:
        raise HTTPException(status_code=403, detail="Only the issue author can delete it")
    db.delete(issue)
    db.commit()
    return {"status": "deleted"}


def request_out(request: FriendRequest, users: dict[int, User]) -> FriendRequestOut:
    requester = users[request.requester_id]
    addressee = users[request.addressee_id]
    return FriendRequestOut(
        id=request.id,
        requester_id=request.requester_id,
        requester_username=requester.username,
        requester_photo_url=requester.profile_photo_url,
        addressee_id=request.addressee_id,
        addressee_username=addressee.username,
        addressee_photo_url=addressee.profile_photo_url,
        status=request.status,
        created_at=request.created_at,
    )


@app.get("/users/{user_id}/friends", response_model=FriendsOut)
def friends(user_id: int, user: User = Depends(current_user), db: Session = Depends(get_db)):
    require_identity(user_id, user)
    current_user = db.get(User, user_id)
    if current_user is None:
        raise HTTPException(status_code=404, detail="User not found")

    users = {user.id: user for user in db.scalars(select(User)).all()}
    requests = db.scalars(
        select(FriendRequest).where(
            or_(FriendRequest.requester_id == user_id, FriendRequest.addressee_id == user_id)
        )
    ).all()

    incoming = [request for request in requests if request.addressee_id == user_id and request.status == "pending"]
    outgoing = [request for request in requests if request.requester_id == user_id and request.status == "pending"]
    accepted = [request for request in requests if request.status == "accepted"]
    friend_ids = {
        request.addressee_id if request.requester_id == user_id else request.requester_id
        for request in accepted
    }
    connected_ids = friend_ids | {request.requester_id for request in incoming} | {request.addressee_id for request in outgoing}
    connected_ids.add(user_id)

    prospective = [user for user in users.values() if user.id not in connected_ids]
    return FriendsOut(
        friends=[users[friend_id] for friend_id in friend_ids if friend_id in users],
        incoming=[request_out(request, users) for request in incoming],
        outgoing=[request_out(request, users) for request in outgoing],
        prospective=prospective,
    )


@app.post("/friend-requests", response_model=FriendRequestOut, status_code=status.HTTP_201_CREATED)
def create_friend_request(payload: FriendRequestCreate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    require_identity(payload.requester_id, user)
    if payload.requester_id == payload.addressee_id:
        raise HTTPException(status_code=400, detail="You cannot add yourself")
    requester = db.get(User, payload.requester_id)
    addressee = db.get(User, payload.addressee_id)
    if requester is None or addressee is None:
        raise HTTPException(status_code=404, detail="User not found")

    request = FriendRequest(requester_id=payload.requester_id, addressee_id=payload.addressee_id)
    db.add(request)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Friend request already exists") from exc
    db.refresh(request)
    return request_out(request, {requester.id: requester, addressee.id: addressee})


@app.patch("/friend-requests/{request_id}", response_model=FriendRequestOut)
def update_friend_request(request_id: int, payload: FriendRequestAction, user: User = Depends(current_user), db: Session = Depends(get_db)):
    request = db.get(FriendRequest, request_id)
    if request is None:
        raise HTTPException(status_code=404, detail="Friend request not found")
    if request.addressee_id != user.id:
        raise HTTPException(status_code=403, detail="Only the recipient can update this request")
    request.status = payload.status
    db.commit()
    db.refresh(request)
    users = {user.id: user for user in db.scalars(select(User)).all()}
    return request_out(request, users)
