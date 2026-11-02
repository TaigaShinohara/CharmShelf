#!/usr/bin/env python3
"""Stop Play uploads until a publisher-capable credential is explicitly adopted.

This policy does not inspect credentials or contact Google Play. Read-only
authentication and local artifact builds remain separate from publication.
"""
import argparse

PUBLISH_LANES = frozenset({"internal", "beta", "release"})
BLOCKED_MESSAGE = (
    "GOOGLE_PLAY_PUBLICATION_BLOCKED: Google Play publication is not configured. "
    "The migrated credential is documented as read-only; publishing permissions "
    "have not been verified. No signing, build or upload will be started by this "
    "entry point. See auth/README.md#google-play-publication."
)


def require_publication_ready(lane):
    if lane in PUBLISH_LANES:
        # No environment-variable override: enabling publication needs a reviewed
        # follow-up after the target app, credential and permission are verified.
        raise SystemExit(BLOCKED_MESSAGE)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lane", choices=sorted(PUBLISH_LANES | {"firebase"}))
    require_publication_ready(parser.parse_args().lane)


if __name__ == "__main__":
    main()
