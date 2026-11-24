#!/usr/bin/env python3
"""Generate the text-layer PDF fixture used by the text integration tests.

The tests need a document whose text content is known exactly, so that a search
can assert both the number of matches and the page each one lands on. No PDF
tool is assumed to be installed, so a minimal PDF 1.4 file is written directly
here with uncompressed content streams and one of the standard 14 fonts.

Layout (see WORDS below):

    page 0: "Alpha searchable Beta"   -> 1 match for "searchable"
    page 1: "Gamma Delta"             -> 0 matches
    page 2: "searchable Epsilon"      -> 1 match
            "searchable again"        -> 1 match

So "searchable" has 3 matches, on pages 0, 2 and 2, and "Gamma" has exactly one
on page 1. "SEARCHABLE" in caps appears nowhere, which is what makes the
case-sensitivity assertion meaningful.

Usage: python3 scripts/make_text_pdf.py [output.pdf]
"""

import sys
from pathlib import Path

# Each entry is one page: a list of text lines drawn top-down.
WORDS = [
    ["Alpha searchable Beta"],
    ["Gamma Delta"],
    ["searchable Epsilon", "searchable again"],
]


def escape(text: str) -> str:
    """Escapes a string for a PDF literal string object."""
    return text.replace("\\", r"\\").replace("(", r"\(").replace(")", r"\)")


def content_stream(lines: list[str]) -> bytes:
    """Builds an uncompressed content stream drawing `lines` at 24pt."""
    out = ["BT", "/F1 24 Tf", "72 720 Td", "28 TL"]
    for index, line in enumerate(lines):
        if index:
            out.append("T*")
        out.append(f"({escape(line)}) Tj")
    out.append("ET")
    return "\n".join(out).encode("ascii")


def build_pdf() -> bytes:
    # Object 1 = catalog, 2 = pages, 3 = font, then per page: page + contents.
    page_count = len(WORDS)
    first_page_obj = 4
    kids = " ".join(f"{first_page_obj + i * 2} 0 R" for i in range(page_count))

    objects: list[bytes] = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        f"<< /Type /Pages /Kids [{kids}] /Count {page_count} >>".encode("ascii"),
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]

    for index, lines in enumerate(WORDS):
        contents_obj = first_page_obj + index * 2 + 1
        objects.append(
            (
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
                "/Resources << /Font << /F1 3 0 R >> >> "
                f"/Contents {contents_obj} 0 R >>"
            ).encode("ascii")
        )
        stream = content_stream(lines)
        objects.append(
            b"<< /Length " + str(len(stream)).encode("ascii") + b" >>\nstream\n"
            + stream
            + b"\nendstream"
        )

    out = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{number} 0 obj\n".encode("ascii") + body + b"\nendobj\n"

    xref_offset = len(out)
    out += f"xref\n0 {len(objects) + 1}\n".encode("ascii")
    out += b"0000000000 65535 f \n"
    for offset in offsets[1:]:
        out += f"{offset:010d} 00000 n \n".encode("ascii")
    out += (
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
        f"startxref\n{xref_offset}\n%%EOF\n"
    ).encode("ascii")
    return bytes(out)


def main() -> None:
    destination = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else Path(__file__).resolve().parent.parent
        / "packages/flutter_pdfview/example/assets/demo-text.pdf"
    )
    destination.write_bytes(build_pdf())
    print(f"wrote {destination} ({destination.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
