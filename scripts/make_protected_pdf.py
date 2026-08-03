#!/usr/bin/env python3
"""Generate the password-protected PDF fixture used by the example app and the
integration tests.

The fixture needs the standard security handler that both Pdfium (Android) and
PDFKit (iOS) implement, and it has to stay small enough to live in the
repository. No PDF tool is assumed to be installed, so the 40-bit RC4 variant
(V=1 / R=2) from PDF 1.4 is written directly here — it needs nothing beyond MD5
from the standard library.

User and owner passwords differ so tests can tell the two apart, and the output
is deterministic so the checked-in fixture stays stable.

Usage: python3 scripts/make_protected_pdf.py [output.pdf]
"""

import hashlib
import struct
import sys
from pathlib import Path

USER_PASSWORD = "hunter2"
OWNER_PASSWORD = "0wn3r-s3cret"

# Table 3.14 in the PDF 1.4 spec: the string every password is padded with.
PADDING = bytes(
    [
        0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41,
        0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
        0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
        0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
    ]
)

# All operations permitted. The reserved high bits of /P are 1 for R=2, which
# -1 satisfies; viewers that honour permissions then impose no restrictions.
PERMISSIONS = -1

KEY_LENGTH = 5  # 40 bits

# A fixed /ID so the encryption key — and therefore the whole file — is stable.
FILE_ID = bytes.fromhex("6cf4f9a2b1e04d7c8a3f5b2e19d0c674")


def rc4(key: bytes, data: bytes) -> bytes:
    state = list(range(256))
    j = 0
    for i in range(256):
        j = (j + state[i] + key[i % len(key)]) % 256
        state[i], state[j] = state[j], state[i]

    out = bytearray(len(data))
    i = j = 0
    for index, byte in enumerate(data):
        i = (i + 1) % 256
        j = (j + state[i]) % 256
        state[i], state[j] = state[j], state[i]
        out[index] = byte ^ state[(state[i] + state[j]) % 256]
    return bytes(out)


def pad_password(password: str) -> bytes:
    raw = password.encode("latin-1")[:32]
    return raw + PADDING[: 32 - len(raw)]


def owner_entry(owner_password: str, user_password: str) -> bytes:
    """Algorithm 3: the /O entry."""
    digest = hashlib.md5(pad_password(owner_password or user_password)).digest()
    return rc4(digest[:KEY_LENGTH], pad_password(user_password))


def encryption_key(user_password: str, o_entry: bytes) -> bytes:
    """Algorithm 2: the file encryption key."""
    digest = hashlib.md5(
        pad_password(user_password)
        + o_entry
        + struct.pack("<i", PERMISSIONS)
        + FILE_ID
    ).digest()
    return digest[:KEY_LENGTH]


def user_entry(key: bytes) -> bytes:
    """Algorithm 4: the /U entry for revision 2."""
    return rc4(key, PADDING)


def object_key(key: bytes, obj_num: int, gen_num: int) -> bytes:
    """Algorithm 1: the per-object key."""
    extended = (
        key
        + struct.pack("<i", obj_num)[:3]
        + struct.pack("<i", gen_num)[:2]
    )
    return hashlib.md5(extended).digest()[: min(len(key) + 5, 16)]


def pdf_string(raw: bytes) -> bytes:
    r"""Serialise bytes as a literal PDF string, escaping what must be escaped."""
    out = bytearray(b"(")
    for byte in raw:
        if byte in (0x28, 0x29, 0x5C):  # ( ) \
            out.append(0x5C)
            out.append(byte)
        elif byte == 0x0D:
            out += b"\\r"
        elif byte == 0x0A:
            out += b"\\n"
        else:
            out.append(byte)
    out += b")"
    return bytes(out)


def content_stream(text: str) -> bytes:
    return (
        b"BT\n/F1 24 Tf\n72 700 Td\n("
        + text.encode("latin-1")
        + b") Tj\nET\n"
    )


def build(user_password: str, owner_password: str) -> bytes:
    o_entry = owner_entry(owner_password, user_password)
    key = encryption_key(user_password, o_entry)
    u_entry = user_entry(key)

    page_one = content_stream("Protected page 1")
    page_two = content_stream("Protected page 2")

    def stream_object(obj_num: int, payload: bytes) -> bytes:
        encrypted = rc4(object_key(key, obj_num, 0), payload)
        return (
            b"<< /Length "
            + str(len(encrypted)).encode("ascii")
            + b" >>\nstream\n"
            + encrypted
            + b"\nendstream"
        )

    objects = {
        1: b"<< /Type /Catalog /Pages 2 0 R >>",
        2: b"<< /Type /Pages /Kids [3 0 R 6 0 R] /Count 2 >>",
        3: (
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
            b"/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>"
        ),
        4: stream_object(4, page_one),
        5: b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        6: (
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
            b"/Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>"
        ),
        7: stream_object(7, page_two),
        # The encryption dictionary is never itself encrypted.
        8: (
            b"<< /Filter /Standard /V 1 /R 2 /O "
            + pdf_string(o_entry)
            + b" /U "
            + pdf_string(u_entry)
            + b" /P "
            + str(PERMISSIONS).encode("ascii")
            + b" >>"
        ),
    }

    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = {}
    for obj_num in sorted(objects):
        offsets[obj_num] = len(out)
        out += str(obj_num).encode("ascii") + b" 0 obj\n"
        out += objects[obj_num]
        out += b"\nendobj\n"

    xref_offset = len(out)
    out += b"xref\n0 " + str(len(objects) + 1).encode("ascii") + b"\n"
    out += b"0000000000 65535 f \n"
    for obj_num in sorted(objects):
        out += ("%010d 00000 n \n" % offsets[obj_num]).encode("ascii")

    file_id = pdf_string(FILE_ID)
    out += (
        b"trailer\n<< /Size "
        + str(len(objects) + 1).encode("ascii")
        + b" /Root 1 0 R /Encrypt 8 0 R /ID ["
        + file_id
        + file_id
        + b"] >>\nstartxref\n"
        + str(xref_offset).encode("ascii")
        + b"\n%%EOF\n"
    )
    return bytes(out)


def main() -> int:
    destination = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else Path(__file__).resolve().parent.parent / "example/assets/demo-protected.pdf"
    )
    destination.write_bytes(build(USER_PASSWORD, OWNER_PASSWORD))
    print(
        f"wrote {destination} ({destination.stat().st_size} bytes), "
        f"user password {USER_PASSWORD!r}, owner password {OWNER_PASSWORD!r}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
