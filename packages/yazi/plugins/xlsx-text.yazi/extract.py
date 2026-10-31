#!/usr/bin/env python3
"""Render a bounded, plain-text preview of an Excel workbook for Yazi."""

from __future__ import annotations

import sys
from pathlib import Path

from openpyxl import load_workbook


MAX_SHEETS = 5
MAX_ROWS = 100
MAX_COLUMNS = 20
MAX_CELL_LENGTH = 80


def render_value(value: object) -> str:
    """Return one cell value in a single, bounded text line."""
    if value is None:
        return ""
    text = str(value).replace("\r", " ").replace("\n", " ").replace("\t", " ")
    return text if len(text) <= MAX_CELL_LENGTH else f"{text[: MAX_CELL_LENGTH - 1]}…"


def main() -> int:
    """Print a compact table preview without modifying the workbook."""
    if len(sys.argv) != 2:
        print("usage: extract.py WORKBOOK", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    try:
        workbook = load_workbook(path, read_only=True, data_only=True)
    except Exception as error:  # openpyxl has several format-specific errors.
        print(f"Unable to read workbook: {error}", file=sys.stderr)
        return 1

    try:
        for sheet_index, sheet in enumerate(workbook.worksheets[:MAX_SHEETS], start=1):
            if sheet_index > 1:
                print()
            print(f"=== Sheet: {sheet.title} ===")
            for row in sheet.iter_rows(max_row=MAX_ROWS, max_col=MAX_COLUMNS, values_only=True):
                print("\t".join(render_value(value) for value in row).rstrip())
            if (
                sheet.max_row is None
                or sheet.max_column is None
                or sheet.max_row > MAX_ROWS
                or sheet.max_column > MAX_COLUMNS
            ):
                print(f"… preview limited to {MAX_ROWS} rows × {MAX_COLUMNS} columns")
        if len(workbook.worksheets) > MAX_SHEETS:
            print(f"\n… preview limited to the first {MAX_SHEETS} sheets")
    finally:
        workbook.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
