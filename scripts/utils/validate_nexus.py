#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

VALID_CHARS = set("ACGTUNRYSWKMBDHV-?acgtunryswkmbdhv")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_nexus.py <file.nexus>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8", errors="replace")
    lower = text.lower()

    if "#nexus" not in lower:
        print("ERROR: missing #NEXUS header", file=sys.stderr)
        return 1

    matrix_pos = lower.find("matrix")
    if matrix_pos == -1:
        print("ERROR: missing MATRIX block", file=sys.stderr)
        return 1

    after = text[matrix_pos + len("matrix") :]
    lines = after.splitlines()

    records = []
    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith(";"):
            break
        if line.startswith("["):
            continue

        parts = line.split()
        if len(parts) < 2:
            continue

        taxon = parts[0]
        seq = "".join(parts[1:])

        if not taxon:
            print("ERROR: empty taxon name in MATRIX", file=sys.stderr)
            return 1
        if not seq:
            print(f"ERROR: empty sequence for taxon '{taxon}'", file=sys.stderr)
            return 1

        bad = sorted(set(seq) - VALID_CHARS)
        if bad:
            print(
                f"ERROR: invalid characters in taxon '{taxon}': {' '.join(bad)}",
                file=sys.stderr,
            )
            return 1

        records.append((taxon, seq))

    if len(records) < 2:
        print("ERROR: NEXUS matrix must contain at least 2 taxa", file=sys.stderr)
        return 1

    lengths = {len(seq) for _, seq in records}
    if len(lengths) != 1:
        print(
            f"ERROR: inconsistent sequence lengths in NEXUS matrix: {sorted(lengths)}",
            file=sys.stderr,
        )
        return 1

    aln_len = next(iter(lengths))
    print(f"OK: {path}")
    print(f"  taxa: {len(records)}")
    print(f"  alignment_length: {aln_len}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())