#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

VALID_CHARS = set("ACGTUNRYSWKMBDHV-?acgtunryswkmbdhv")


def read_fasta(path: Path):
    records = []
    header = None
    seq_chunks = []

    with path.open("r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, start=1):
            line = line.rstrip("\n")
            if not line.strip():
                continue
            if line.startswith(">"):
                if header is not None:
                    seq = "".join(seq_chunks)
                    records.append((header, seq))
                header = line[1:].strip()
                seq_chunks = []
                if not header:
                    raise ValueError(f"Empty FASTA header at line {lineno}")
            else:
                if header is None:
                    raise ValueError(f"Sequence data before first header at line {lineno}")
                seq_chunks.append(line.strip())

    if header is not None:
        seq = "".join(seq_chunks)
        records.append((header, seq))

    return records


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_fasta.py <aligned_fasta>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 1

    records = read_fasta(path)

    if len(records) < 2:
        print("ERROR: FASTA must contain at least 2 sequences", file=sys.stderr)
        return 1

    lengths = set()
    for idx, (header, seq) in enumerate(records, start=1):
        if not header:
            print(f"ERROR: empty header in record {idx}", file=sys.stderr)
            return 1
        if not seq:
            print(f"ERROR: empty sequence for header '{header}'", file=sys.stderr)
            return 1

        bad = sorted(set(seq) - VALID_CHARS)
        if bad:
            print(
                f"ERROR: invalid characters in '{header}': {' '.join(bad)}",
                file=sys.stderr,
            )
            return 1

        # WARNING: demasiadas Ns (ambigüedad)
        n_count = seq.upper().count("N")
        if n_count > 10:
            print(
                f"WARNING: '{header}' has {n_count} Ns (ambiguous bases)",
                file=sys.stderr,
            )

        lengths.add(len(seq))

    aln_len = next(iter(lengths))
    print(f"OK: {path}")
    print(f"  sequences: {len(records)}")
    print(f"  alignment_length: {aln_len}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())