#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path, help="Path to YAML config file")
    parser.add_argument("key", help="Dot-separated key, e.g. mrbayes.nst")
    args = parser.parse_args()

    if not args.config.exists():
        print(f"ERROR: config file not found: {args.config}", file=sys.stderr)
        return 1

    with args.config.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    value = data
    for part in args.key.split("."):
        if not isinstance(value, dict) or part not in value:
            print(f"ERROR: key not found: {args.key}", file=sys.stderr)
            return 2
        value = value[part]

    if isinstance(value, bool):
        print(str(value).lower())
    else:
        print(value)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())