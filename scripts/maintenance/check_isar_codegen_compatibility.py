#!/usr/bin/env python3
"""Verify the Isar toolchain port retains its 3.1.0+1 templates and output."""

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / "patches/isar_generator"
BASELINE = PATCH / "generated_baseline.sha256.json"

# Keep literals intact: removing whitespace inside strings would hide changes
# to persisted property/index names. Formatting-only trailing commas are ignored.
LEXEMES = re.compile(
    r"r?(?:\"\"\"[\s\S]*?\"\"\"|'''[\s\S]*?'''|"
    r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*')"
    r"|//[^\n]*|/\*[\s\S]*?\*/|\s+|[A-Za-z_$][\w$]*|\d+(?:\.\d+)?|.",
    re.DOTALL,
)


def output_digest(source: str) -> str:
    tokens = [
        token
        for token in LEXEMES.findall(source)
        if not token.isspace() and not token.startswith(("//", "/*"))
    ]
    tokens = [
        token
        for i, token in enumerate(tokens)
        if not (token == "," and i + 1 < len(tokens) and tokens[i + 1] in ")]}")
    ]
    return hashlib.sha256(json.dumps(tokens, ensure_ascii=False).encode()).hexdigest()


def main() -> None:
    templates = json.loads((PATCH / "upstream_templates.sha256.json").read_text())
    for relative, expected in templates.items():
        actual = hashlib.sha256((PATCH / relative).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f"Isar 3.1.0+1 template changed: {relative}")
    generated = json.loads(BASELINE.read_text())
    for relative, expected in generated["files"].items():
        if output_digest((ROOT / relative).read_text()) != expected:
            raise ValueError(f"Isar generated schema/adapter/query changed: {relative}")
    print(f"Isar 3.1.0+1: {len(templates)} original templates and "
          f"{len(generated['files'])} generated token baselines match")


if __name__ == "__main__":
    main()
