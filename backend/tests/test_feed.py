from fastapi.testclient import TestClient
from uuid import uuid4

from app.main import app


client = TestClient(app)


def signup(username: str) -> tuple[int, dict[str, str]]:
    username = f"{username}-{uuid4().hex[:8]}"
    response = client.post(
        "/auth/signup",
        json={
            "username": username,
            "email": f"{username}@example.test",
            "password": "A-secure-test-password!",
            "time_zone": "UTC",
        },
    )
    assert response.status_code == 201, response.text
    result = response.json()
    return result["user"]["id"], {"Authorization": f"Bearer {result['access_token']}"}


def test_feed_is_paginated_and_contains_multiple_images():
    user_id, headers = signup("feed-owner")
    response = client.post(
        "/newsletters",
        headers=headers,
        json={"title": "The CA newsletter", "owner_id": user_id},
    )
    assert response.status_code == 201, response.text
    newsletter_id = response.json()["id"]

    for index in range(6):
        response = client.post(
            f"/newsletters/{newsletter_id}/issues",
            headers=headers,
            json={
                "author_id": user_id,
                "title": f"Reply {index}",
                "body": f"Text {index}",
                "image_urls": [f"https://images.example.test/{index}-a.jpg", f"https://images.example.test/{index}-b.jpg"],
            },
        )
        assert response.status_code == 201, response.text
        assert len(response.json()["image_urls"]) == 2

    first = client.get(f"/users/{user_id}/feed?limit=5&offset=0", headers=headers)
    assert first.status_code == 200, first.text
    assert len(first.json()["items"]) == 5
    assert first.json()["has_more"] is True
    assert [item["title"] for item in first.json()["items"]] == [f"Reply {index}" for index in range(5, 0, -1)]

    second = client.get(f"/users/{user_id}/feed?limit=5&offset=5", headers=headers)
    assert second.status_code == 200, second.text
    assert [item["title"] for item in second.json()["items"]] == ["Reply 0"]
    assert second.json()["has_more"] is False


def test_feed_rejects_cross_user_access_and_excessive_limit():
    first_id, first_headers = signup("feed-first")
    _, second_headers = signup("feed-second")
    assert client.get(f"/users/{first_id}/feed", headers=second_headers).status_code == 403
    assert client.get(f"/users/{first_id}/feed?limit=51", headers=first_headers).status_code == 422


def test_newsletter_post_requires_title_text_and_safe_image_urls():
    user_id, headers = signup("post-validation-owner")
    newsletter = client.post(
        "/newsletters", headers=headers, json={"title": "Validated newsletter", "owner_id": user_id}
    )
    newsletter_id = newsletter.json()["id"]

    blank = client.post(
        f"/newsletters/{newsletter_id}/issues",
        headers=headers,
        json={"author_id": user_id, "title": "   ", "body": "Text"},
    )
    assert blank.status_code == 422

    unsafe = client.post(
        f"/newsletters/{newsletter_id}/issues",
        headers=headers,
        json={
            "author_id": user_id,
            "title": "A title",
            "body": "Text",
            "image_urls": ["javascript:alert(1)"],
        },
    )
    assert unsafe.status_code == 422

    created = client.post(
        f"/newsletters/{newsletter_id}/issues",
        headers=headers,
        json={
            "author_id": user_id,
            "title": " A title ",
            "body": " Some text ",
            "image_urls": ["/uploads/photo.png", "https://images.example.test/photo.jpg"],
        },
    )
    assert created.status_code == 201, created.text
    assert created.json()["title"] == "A title"
    assert created.json()["body"] == "Some text"
    assert created.json()["image_urls"] == [
        "/uploads/photo.png",
        "https://images.example.test/photo.jpg",
    ]


def test_private_newsletter_comments_are_not_exposed_by_issue_id():
    owner_id, owner_headers = signup("private-reply-owner")
    outsider_id, outsider_headers = signup("private-reply-outsider")
    newsletter = client.post(
        "/newsletters",
        headers=owner_headers,
        json={"title": "Private newsletter", "owner_id": owner_id, "visibility": "private"},
    )
    issue = client.post(
        f"/newsletters/{newsletter.json()['id']}/issues",
        headers=owner_headers,
        json={"author_id": owner_id, "title": "Private post", "body": "Private text"},
    )
    issue_id = issue.json()["id"]

    assert client.get(f"/issues/{issue_id}/replies", headers=outsider_headers).status_code == 403
    response = client.post(
        f"/issues/{issue_id}/replies",
        headers=outsider_headers,
        json={"author_id": outsider_id, "body": "I should not see this"},
    )
    assert response.status_code == 403

    blank = client.post(
        f"/issues/{issue_id}/replies",
        headers=owner_headers,
        json={"author_id": owner_id, "body": "   "},
    )
    assert blank.status_code == 422
