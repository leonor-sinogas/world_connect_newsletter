"""Keep the test suite completely isolated from the developer database.

This module is loaded by pytest before it imports either test module.  That
ordering matters because ``app.database`` creates its engine at import time.
Using a unique on-disk SQLite database also makes this safe for parallel test
workers and avoids the connection-sharing pitfalls of SQLite ``:memory:``.
"""

import os
import shutil
import tempfile
from pathlib import Path


_TEST_DATABASE_DIR = Path(tempfile.mkdtemp(prefix="world-connect-tests-"))
_TEST_DATABASE_PATH = _TEST_DATABASE_DIR / "newsletter_test.db"

# Settings reads DATABASE_URL while app.main is imported by the test modules.
os.environ["DATABASE_URL"] = f"sqlite:///{_TEST_DATABASE_PATH}"


def pytest_sessionfinish(session, exitstatus):  # noqa: ARG001
    """Close SQLite connections before deleting the temporary database."""

    try:
        from app.database import engine

        engine.dispose()
    finally:
        shutil.rmtree(_TEST_DATABASE_DIR, ignore_errors=True)
