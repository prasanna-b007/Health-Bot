import os
import sys

import pytest

# Tests import `actions.*` directly; make the backend package root importable
# whether pytest is invoked from the repo root or from backend/.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from actions import datastore  # noqa: E402


@pytest.fixture(scope="session")
def kb():
    """The real knowledge base, loaded once for the whole test session."""
    return datastore.load()
