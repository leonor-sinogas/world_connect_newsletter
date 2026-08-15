from io import BytesIO
from pathlib import Path
from uuid import uuid4

from fastapi.testclient import TestClient
from PIL import Image

from app.main import UPLOAD_DIR, app


client = TestClient(app)


def auth_headers() -> dict[str, str]:
    username = f"upload-{uuid4().hex}"
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
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def uploaded_path(response) -> Path:
    return UPLOAD_DIR / response.json()["url"].rsplit("/", 1)[-1]


def image_bytes(image_format: str) -> bytes:
    buffer = BytesIO()
    Image.new("RGB", (2, 2), color="purple").save(buffer, format=image_format)
    return buffer.getvalue()


def test_upload_accepts_png_with_browser_octet_stream_and_removes_user_filename():
    contents = image_bytes("PNG")
    response = client.post(
        "/uploads",
        headers=auth_headers(),
        files={"file": ("profile.png", contents, "application/octet-stream")},
    )
    assert response.status_code == 200, response.text
    path = uploaded_path(response)
    try:
        assert path.suffix == ".png"
        assert path.name != "profile.png"
        assert path.read_bytes() == contents
    finally:
        path.unlink(missing_ok=True)


def test_upload_accepts_jpg_and_normalizes_jpeg_extension():
    contents = image_bytes("JPEG")
    response = client.post(
        "/uploads",
        headers=auth_headers(),
        files={"file": ("photo.jpeg", contents, "image/jpeg")},
    )
    assert response.status_code == 200, response.text
    path = uploaded_path(response)
    try:
        assert path.suffix == ".jpg"
        assert path.read_bytes() == contents
    finally:
        path.unlink(missing_ok=True)


def test_upload_rejects_invalid_bytes_and_mismatched_metadata():
    headers = auth_headers()
    invalid = client.post(
        "/uploads",
        headers=headers,
        files={"file": ("fake.png", b"not an image", "image/png")},
    )
    assert invalid.status_code == 400

    mismatch = client.post(
        "/uploads",
        headers=headers,
        files={"file": ("fake.jpg", b"\x89PNG\r\n\x1a\ncontent", "image/jpeg")},
    )
    assert mismatch.status_code == 400


def test_upload_rejects_more_than_five_mb():
    response = client.post(
        "/uploads",
        headers=auth_headers(),
        files={"file": ("large.png", b"\x89PNG\r\n\x1a\n" + b"x" * (5 * 1024 * 1024), "image/png")},
    )
    assert response.status_code == 400
    assert "5 MB" in response.json()["detail"]
