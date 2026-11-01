#!/usr/bin/env python3
"""Render bounded plain-text previews of OpenDocument files for Yazi."""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree


MAX_CONTENT_XML_BYTES = 20 * 1024 * 1024
MAX_SHEETS = 5
MAX_ROWS = 100
MAX_COLUMNS = 20
MAX_CELL_LENGTH = 80

NS = {
    "office": "urn:oasis:names:tc:opendocument:xmlns:office:1.0",
    "table": "urn:oasis:names:tc:opendocument:xmlns:table:1.0",
    "text": "urn:oasis:names:tc:opendocument:xmlns:text:1.0",
}


def qualified(namespace: str, name: str) -> str:
    """Return an ElementTree-qualified ODF element or attribute name."""
    return f"{{{NS[namespace]}}}{name}"


def compact(value: object) -> str:
    """Return one value as a single bounded preview cell."""
    text = " ".join(str(value).replace("\t", " ").split())
    return text if len(text) <= MAX_CELL_LENGTH else f"{text[: MAX_CELL_LENGTH - 1]}…"


def read_content_xml(path: Path) -> ElementTree.Element:
    """Load the ODF content XML with a bounded decompressed size."""
    try:
        with zipfile.ZipFile(path) as archive:
            info = archive.getinfo("content.xml")
            if info.file_size > MAX_CONTENT_XML_BYTES:
                raise ValueError("content.xml exceeds the preview size limit")
            return ElementTree.fromstring(archive.read(info))
    except (KeyError, zipfile.BadZipFile, ElementTree.ParseError, OSError, ValueError) as error:
        raise ValueError(f"Unable to read OpenDocument file: {error}") from error


def render_text(root: ElementTree.Element) -> None:
    """Print paragraphs and headings from Writer or Impress content."""
    paragraph_tags = {qualified("text", "p"), qualified("text", "h")}
    for element in root.iter():
        if element.tag in paragraph_tags:
            value = compact("".join(element.itertext()))
            if value:
                print(value)


def render_sheet(sheet: ElementTree.Element) -> None:
    """Print a bounded TSV preview for one Calc sheet."""
    rows_rendered = 0
    for row in sheet.findall(qualified("table", "table-row")):
        if rows_rendered >= MAX_ROWS:
            break
        repeat_rows = int(row.get(qualified("table", "number-rows-repeated"), "1"))
        values: list[str] = []
        for cell in row:
            if cell.tag not in {qualified("table", "table-cell"), qualified("table", "covered-table-cell")}:
                continue
            repeat_columns = int(cell.get(qualified("table", "number-columns-repeated"), "1"))
            value = compact("".join(cell.itertext()))
            if not value:
                value = compact(cell.get(qualified("office", "value"), ""))
            values.extend([value] * min(repeat_columns, MAX_COLUMNS - len(values)))
            if len(values) >= MAX_COLUMNS:
                break
        for _ in range(min(repeat_rows, MAX_ROWS - rows_rendered)):
            print("\t".join(values).rstrip())
            rows_rendered += 1

    if rows_rendered >= MAX_ROWS:
        print(f"… preview limited to {MAX_ROWS} rows × {MAX_COLUMNS} columns")


def render_spreadsheet(root: ElementTree.Element) -> None:
    """Print a bounded preview for the first sheets in a Calc workbook."""
    sheets = root.findall(f".//{qualified('table', 'table')}")
    for index, sheet in enumerate(sheets[:MAX_SHEETS], start=1):
        if index > 1:
            print()
        print(f"=== Sheet: {sheet.get(qualified('table', 'name'), f'Sheet {index}')} ===")
        render_sheet(sheet)
    if len(sheets) > MAX_SHEETS:
        print(f"\n… preview limited to the first {MAX_SHEETS} sheets")


def main() -> int:
    """Print a local, read-only preview for an ODF file."""
    if len(sys.argv) != 2:
        print("usage: extract.py OPEN_DOCUMENT", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    try:
        root = read_content_xml(path)
        if path.suffix.casefold() in {".ods", ".ots"}:
            render_spreadsheet(root)
        else:
            render_text(root)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
