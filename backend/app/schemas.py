from datetime import datetime

from pydantic import BaseModel, Field


class NewsletterCreate(BaseModel):
    owner_id: int | None = None
    title: str = Field(min_length=1, max_length=120)
    description: str = Field(default="", max_length=20000)
    visibility: str = Field(default="public", pattern="^(public|private)$")
    category: str = Field(default="friends", min_length=1, max_length=80)
    image_url: str = Field(default="", max_length=2048)
    invitee_ids: list[int] = Field(default_factory=list, max_length=100)


class NewsletterTransfer(BaseModel):
    new_owner_id: int


class NewsletterOut(BaseModel):
    id: int
    owner_id: int | None
    title: str
    description: str
    visibility: str
    category: str
    image_url: str = ""
    created_at: datetime
    is_subscribed: bool = False
    can_invite: bool = False
    can_join: bool = False
    join_status: str | None = None
    share_url: str | None = None

    model_config = {"from_attributes": True}


class AdminNewsletterOut(BaseModel):
    id: int
    owner_id: int | None
    owner_username: str = ""
    title: str
    description: str
    visibility: str
    category: str
    created_at: datetime


class IssueCreate(BaseModel):
    author_id: int
    title: str = Field(min_length=1, max_length=160)
    body: str = Field(min_length=1, max_length=12000)
    image_urls: list[str] = Field(default_factory=list, max_length=10)
    # Kept during the client migration; new clients should use image_urls.
    photo_url: str = Field(default="", max_length=2048)


class IssueOut(BaseModel):
    id: int
    newsletter_id: int
    author_id: int | None
    title: str
    body: str
    photo_url: str
    image_urls: list[str] = Field(default_factory=list)
    created_at: datetime
    newsletter_title: str = ""
    author_name: str = ""
    replies: list["ReplyOut"] = []

    model_config = {"from_attributes": True}


class FeedOut(BaseModel):
    items: list[IssueOut]
    limit: int
    offset: int
    has_more: bool


class ReplyCreate(BaseModel):
    author_id: int
    body: str = Field(default="", max_length=300)
    image_url: str = Field(default="", max_length=2048)


class ReplyOut(BaseModel):
    id: int
    issue_id: int
    author_id: int | None
    author_name: str
    author_photo_url: str = ""
    body: str
    image_url: str = ""
    created_at: datetime

    model_config = {"from_attributes": True}


class UserCreate(BaseModel):
    username: str = Field(min_length=2, max_length=80)
    email: str = Field(min_length=5, max_length=160)
    password: str = Field(min_length=12, max_length=120)
    time_zone: str = "GMT"


class UserLogin(BaseModel):
    username: str = Field(min_length=2, max_length=80)
    password: str = Field(min_length=1, max_length=120)


class UserOut(BaseModel):
    id: int
    username: str
    email: str
    profile_photo_url: str
    time_zone: str
    appearance: str = "system"
    is_admin: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


class AuthOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class AdminPasswordUpdate(BaseModel):
    password: str = Field(min_length=12, max_length=120)


class ProfileUpdate(BaseModel):
    profile_photo_url: str = ""
    time_zone: str = "GMT"
    appearance: str = Field(default="system", pattern="^(system|light|dark)$")


class PasswordResetRequest(BaseModel):
    email: str = Field(min_length=5, max_length=160)


class PasswordResetVerify(BaseModel):
    email: str = Field(min_length=5, max_length=160)
    code: str = Field(min_length=6, max_length=6)


class PasswordResetComplete(BaseModel):
    email: str = Field(min_length=5, max_length=160)
    code: str = Field(min_length=6, max_length=6)
    password: str = Field(min_length=12, max_length=120)


class FriendRequestCreate(BaseModel):
    requester_id: int
    addressee_id: int


class FriendRequestAction(BaseModel):
    status: str = Field(pattern="^(accepted|rejected)$")


class FriendRequestOut(BaseModel):
    id: int
    requester_id: int
    requester_username: str
    requester_photo_url: str = ""
    addressee_id: int
    addressee_username: str
    addressee_photo_url: str = ""
    status: str
    created_at: datetime


class FriendsOut(BaseModel):
    friends: list[UserOut]
    incoming: list[FriendRequestOut]
    outgoing: list[FriendRequestOut]
    prospective: list[UserOut]


class NewsletterInviteCreate(BaseModel):
    inviter_id: int
    invitee_id: int


class NewsletterInvitationOut(BaseModel):
    id: int
    newsletter_id: int
    inviter_id: int
    inviter_username: str
    invitee_id: int
    invitee_username: str
    created_at: datetime


class NewsletterShareLinkOut(BaseModel):
    share_url: str


class SharedNewsletterOut(BaseModel):
    id: int
    title: str
    description: str
    image_url: str
    category: str
    owner_username: str
