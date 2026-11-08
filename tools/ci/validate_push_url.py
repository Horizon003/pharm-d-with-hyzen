"""Normalize copy/paste whitespace, then enforce the owner-selected public API."""
import os
from pathlib import Path

expected = "https://hyzen-onesignal-sender.harisaslam003.workers.dev"
configured = "".join(os.environ.get("PUSH_API_BASE", "").split()).rstrip("/")
if configured != expected:
    raise SystemExit("HYZEN_PUSH_API_BASE must contain the configured Hyzen Worker HTTPS URL.")
with Path(os.environ["GITHUB_ENV"]).open("a") as output:
    output.write(f"PUSH_API_BASE={expected}\n")
print(f"Verified public push API: {expected}")
