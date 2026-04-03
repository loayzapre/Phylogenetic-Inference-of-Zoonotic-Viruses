#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from io import StringIO
from pathlib import Path

import matplotlib.pyplot as plt
from Bio import Phylo


def extract_translate_map(text: str) -> dict[str, str]:
    """
    Extract NEXUS translate block into a dict like:
        {"1": "Nig1977homo", "2": "Sier2012nat1", ...}
    """
    m = re.search(
        r"(?is)\btranslate\b(.*?);",
        text,
    )
    if not m:
        return {}

    block = m.group(1)
    translate = {}

    # matches lines like:
    # 1 Nig1977homo,
    # 35 Sier2011homo0
    for num, label in re.findall(r"(\d+)\s+([^,\s;]+)\s*[,;]?", block):
        translate[num] = label

    return translate


def extract_newick_from_text(text: str, source: str = "<memory>") -> str:
    """
    Extract the first tree definition from NEXUS/plain text.
    Handles lines like:
        tree con_50_majrule = [&U] (...);
    """
    m = re.search(
        r"^\s*tree\b.*?=\s*(?:\[[^\]]*\]\s*)?(\(.*?;)\s*$",
        text,
        flags=re.IGNORECASE | re.MULTILINE | re.DOTALL,
    )
    if m:
        return m.group(1)

    m2 = re.search(r"(\(.*?;)", text, flags=re.DOTALL)
    if m2:
        return m2.group(1)

    raise ValueError(f"No Newick tree found inside {source}")


def remove_bracket_annotations(newick: str) -> str:
    """
    Remove bracket annotations such as:
      [&prob=...]
      [comment]
    repeatedly until none remain.
    """
    prev = None
    while prev != newick:
        prev = newick
        newick = re.sub(r"\[[^\[\]]*\]", "", newick)
    return newick


def apply_translate_to_newick(newick: str, translate: dict[str, str]) -> str:
    """
    Replace numeric terminal labels in a Newick string using NEXUS translate map.

    We only replace numbers that appear as taxon labels, i.e. when preceded by
    '(' or ',' and followed by one of ':', ',', ')'.
    """
    if not translate:
        return newick

    pattern = re.compile(r'(?P<prefix>\(|,)\s*(?P<num>\d+)\s*(?P<suffix>[:),])')

    def repl(match: re.Match) -> str:
        prefix = match.group("prefix")
        num = match.group("num")
        suffix = match.group("suffix")
        label = translate.get(num, num)

        # Quote labels if they contain special chars/spaces
        if re.search(r"[\s():;,]", label):
            label = f"'{label}'"

        return f"{prefix}{label}{suffix}"

    return pattern.sub(repl, newick)


def load_tree(path: Path):
    """
    Load tree from NEXUS/Newick.

    Strategy:
    1. Try Bio.Phylo nexus reader directly.
    2. If that fails, manually:
       - read text
       - extract translate block
       - extract tree newick
       - remove annotations
       - apply translate mapping
       - read as plain newick
    """
    suffix = path.suffix.lower()

    if suffix in {".nexus", ".nex", ".tre"}:
        try:
            return Phylo.read(str(path), "nexus")
        except Exception:
            pass

    text = path.read_text(encoding="utf-8", errors="replace")
    translate = extract_translate_map(text)
    newick = extract_newick_from_text(text, source=str(path))
    newick = remove_bracket_annotations(newick)
    newick = apply_translate_to_newick(newick, translate)

    handle = StringIO(newick)
    return Phylo.read(handle, "newick")


def strip_internal_labels(tree) -> None:
    for clade in tree.find_clades():
        if not clade.is_terminal():
            clade.name = None
            if hasattr(clade, "confidence"):
                clade.confidence = None


def render_tree(
    tree,
    title: str,
    out_pdf: Path,
    out_png: Path,
    width: float,
    height: float,
    show_tip_labels: bool,
    show_internal_labels: bool,
) -> None:
    fig = plt.figure(figsize=(width, height))
    ax = fig.add_subplot(1, 1, 1)

    def label_func(clade):
        if clade.is_terminal():
            return clade.name if show_tip_labels else None
        else:
            if show_internal_labels:
                return clade.name
            return None

    Phylo.draw(
        tree,
        do_show=False,
        axes=ax,
        label_func=label_func,
        show_confidence=False,
    )

    if title:
        ax.set_title(title)

    fig.savefig(out_pdf, bbox_inches="tight")
    fig.savefig(out_png, bbox_inches="tight", dpi=300)
    plt.close(fig)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Render one or more phylogenetic trees to PDF and PNG."
    )
    parser.add_argument(
        "tree_files",
        nargs="+",
        help="One or more tree file paths (.tre, .con.tre, .nexus, .nwk, etc.)",
    )
    parser.add_argument(
        "--outdir",
        required=True,
        help="Output directory for rendered figures",
    )
    parser.add_argument(
        "--width",
        type=float,
        default=10.0,
        help="Figure width in inches (default: 10)",
    )
    parser.add_argument(
        "--height",
        type=float,
        default=12.0,
        help="Figure height in inches (default: 12)",
    )
    parser.add_argument(
        "--title-mode",
        choices=["name", "stem", "none"],
        default="name",
        help="How to set plot title: filename, stem, or none",
    )
    parser.add_argument(
        "--show-tip-labels",
        action="store_true",
        help="Show tip (leaf) labels",
    )
    parser.add_argument(
        "--show-internal-labels",
        action="store_true",
        help="Show internal node labels",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    print(f"Rendering {len(args.tree_files)} tree(s) to: {outdir}")

    for tree_str in args.tree_files:
        tree_path = Path(tree_str)

        if not tree_path.exists():
            raise FileNotFoundError(tree_path)

        tree = load_tree(tree_path)
        strip_internal_labels(tree)

        if args.title_mode == "name":
            title = tree_path.name
        elif args.title_mode == "stem":
            title = tree_path.stem
        else:
            title = ""

        basename = tree_path.name
        for ext in [".con.tre", ".tre", ".tree", ".newick", ".nwk", ".nexus", ".nex"]:
            if basename.lower().endswith(ext):
                basename = basename[: -len(ext)]
                break

        if not basename:
            basename = tree_path.stem

        out_pdf = outdir / f"{basename}.pdf"
        out_png = outdir / f"{basename}.png"

        render_tree(
            tree=tree,
            title=title,
            out_pdf=out_pdf,
            out_png=out_png,
            width=args.width,
            height=args.height,
            show_tip_labels=args.show_tip_labels,
            show_internal_labels=args.show_internal_labels,
        )
        print(f"✓ rendered {tree_path}")

    print("All figures exported.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())