#!/usr/bin/env python3
"""Append a job application row to ~/.auto-apply/applications.csv with proper CSV escaping.

Commas and quotes in company names, roles, and notes are common ("Microsoft, Inc.",
"Engineer, Growth") so naive string concatenation corrupts the CSV. Using the stdlib
csv module handles it correctly.

Usage:
  python3 log_application.py \\
    --company "StubHub" \\
    --role "SWE II, Marketplace Ops" \\
    --url "https://job-boards.eu.greenhouse.io/stubhubinc/jobs/4825351101" \\
    --ats greenhouse \\
    --location "New York, NY" \\
    --salary-min 165000 \\
    --salary-max 200000 \\
    --status applied \\
    --notes ""
"""

import argparse
import csv
import datetime
import os
import sys
from pathlib import Path

COLUMNS = [
    "date_applied",
    "company",
    "role",
    "url",
    "ats",
    "location",
    "salary_min",
    "salary_max",
    "status",
    "notes",
]

VALID_STATUS = {"applied", "failed", "skipped"}
VALID_ATS = {"greenhouse", "lever", "ashby"}


def main():
    parser = argparse.ArgumentParser(description="Append a job application to applications.csv")
    parser.add_argument("--company", required=True)
    parser.add_argument("--role", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--ats", required=True, choices=sorted(VALID_ATS))
    parser.add_argument("--location", default="")
    parser.add_argument("--salary-min", default="")
    parser.add_argument("--salary-max", default="")
    parser.add_argument("--status", default="applied", choices=sorted(VALID_STATUS))
    parser.add_argument("--notes", default="")
    parser.add_argument(
        "--csv-path",
        default=str(Path.home() / ".auto-apply" / "applications.csv"),
        help="Override the CSV location (default: ~/.auto-apply/applications.csv)",
    )
    parser.add_argument(
        "--date",
        default=None,
        help="Override the date (YYYY-MM-DD). Defaults to today in local time.",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv_path).expanduser()
    csv_path.parent.mkdir(parents=True, exist_ok=True)

    date_str = args.date or datetime.date.today().isoformat()

    # If the file doesn't exist or is empty, write the header.
    write_header = not csv_path.exists() or csv_path.stat().st_size == 0

    row = [
        date_str,
        args.company,
        args.role,
        args.url,
        args.ats,
        args.location,
        args.salary_min,
        args.salary_max,
        args.status,
        args.notes,
    ]

    with csv_path.open("a", newline="") as f:
        writer = csv.writer(f)
        if write_header:
            writer.writerow(COLUMNS)
        writer.writerow(row)

    print(f"Logged: {args.status} {args.company} - {args.role}")


if __name__ == "__main__":
    main()
