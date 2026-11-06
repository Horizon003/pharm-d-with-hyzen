#!/usr/bin/env python3
"""Offline, read-only question CSV preflight. Does not import/publish questions.

Taxonomy must be supplied explicitly: {"schema_version":1,"years":
{"1":{"subjects":{"exact-subject-id":{"topics":["exact-topic-id"]}}}}}
No sample curriculum, scoring policy or aliases are inferred.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import io
import json
import re
import sys
from collections import Counter
from pathlib import Path

REQUIRED = ("question_id", "professional_year", "subject", "topic", "question",
            "option_a", "option_b", "option_c", "option_d", "correct_option")
OPTIONAL = ("explanation", "difficulty", "status")
COLUMNS = REQUIRED + OPTIONAL
MAX_BYTES, MAX_ROWS, MAX_ERRORS = 2 * 1024 * 1024, 2000, 100
LIMITS = {"question_id": 128, "subject": 150, "topic": 180, "question": 8000,
          "explanation": 12000, **{k: 2000 for k in ("option_a", "option_b", "option_c", "option_d")}}
SAFE_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}\Z")
HTML = re.compile(r"<\s*(?:/?[A-Za-z][^>]*|!DOCTYPE[^>]*)>", re.I)


def check_taxonomy(value: object) -> dict:
    if not isinstance(value, dict) or value.get("schema_version") != 1:
        raise ValueError("Taxonomy schema_version must be 1.")
    years = value.get("years")
    if not isinstance(years, dict) or not years:
        raise ValueError("Supply actual year/subject/topic IDs; no taxonomy is inferred.")
    for year, record in years.items():
        if year not in {"1", "2", "3", "4", "5"} or not isinstance(record, dict):
            raise ValueError("Taxonomy years must use the app's canonical 1–5 values.")
        subjects = record.get("subjects")
        if not isinstance(subjects, dict) or not subjects:
            raise ValueError("Each supplied year needs actual subject IDs.")
        for subject, info in subjects.items():
            topics = info.get("topics") if isinstance(info, dict) else None
            if not isinstance(subject, str) or not subject.strip() or not isinstance(topics, list) or not topics:
                raise ValueError("Every subject needs a nonempty list of actual topic IDs.")
            if any(not isinstance(t, str) or not t.strip() for t in topics) or len(set(topics)) != len(topics):
                raise ValueError("Topic IDs must be distinct, nonempty strings.")
    return years


def preflight(data: bytes, taxonomy: dict, existing_ids=()) -> dict:
    """Return metadata/errors only, never options, explanations or answer keys."""
    years = check_taxonomy(taxonomy)
    result = {"contract": "offline-preflight-v1", "sha256": hashlib.sha256(data).hexdigest(),
              "valid": False, "rows_checked": 0, "valid_rows": 0, "errors": [],
              "coverage": [], "active_rows_requiring_server_approval": 0,
              "published": False, "server_authorization_verified": False}
    errors = result["errors"]
    def error(line: int, field: str, code: str):
        if len(errors) < MAX_ERRORS:
            errors.append({"line": line, "field": field, "code": code})
    if len(data) > MAX_BYTES:
        error(1, "file", "file_exceeds_2_mib"); return result
    try:
        source = data.decode("utf-8-sig", errors="strict")
    except UnicodeDecodeError:
        error(1, "file", "invalid_utf8"); return result
    if "\x00" in source:
        error(1, "file", "nul_byte"); return result
    parser = csv.reader(io.StringIO(source, newline=""), strict=True)
    try:
        header = next(parser, [])
        if len(set(header)) != len(header):
            error(1, "header", "duplicate_column")
        for name in REQUIRED:
            if name not in header: error(1, name, "missing_column")
        if any(h not in COLUMNS for h in header): error(1, "header", "unknown_column")
        if errors: return result
        seen, existing = set(), set(existing_ids)
        coverage = Counter()
        while True:
            start = parser.line_num + 1
            row = next(parser, None)
            if row is None: break
            if not row or all(not cell.strip() for cell in row): continue
            result["rows_checked"] += 1
            if result["rows_checked"] > MAX_ROWS:
                error(start, "file", "more_than_2000_rows"); break
            before = len(errors)
            if len(row) != len(header):
                error(start, "row", "wrong_column_count"); continue
            item = {h: cell.strip() for h, cell in zip(header, row)}
            for field in REQUIRED:
                if not item[field]: error(start, field, "required")
            for field, text in item.items():
                if len(text) > LIMITS.get(field, 128): error(start, field, "too_long")
                if text.startswith(("=", "+", "-", "@")): error(start, field, "spreadsheet_formula_prefix")
                if HTML.search(text): error(start, field, "html_not_allowed")
            qid = item["question_id"]
            if not SAFE_ID.fullmatch(qid): error(start, "question_id", "unsafe_id")
            if qid in seen: error(start, "question_id", "duplicate_in_batch")
            if qid in existing: error(start, "question_id", "existing_id_requires_revision_review")
            seen.add(qid)
            year, subject, topic = (item[k] for k in ("professional_year", "subject", "topic"))
            subjects = years.get(year, {}).get("subjects", {})
            if year not in years: error(start, "professional_year", "unknown_year")
            elif subject not in subjects: error(start, "subject", "unknown_subject_for_year")
            elif topic not in subjects[subject]["topics"]: error(start, "topic", "unknown_topic_for_subject")
            if len(item["question"]) < 5: error(start, "question", "stem_too_short")
            options = [item[k].casefold() for k in ("option_a", "option_b", "option_c", "option_d")]
            if len(set(options)) != 4: error(start, "options", "options_must_be_distinct")
            if item["correct_option"] not in {"A", "B", "C", "D"}: error(start, "correct_option", "must_be_A_B_C_D")
            if item.get("difficulty", "") not in {"", "easy", "medium", "hard"}: error(start, "difficulty", "unknown_difficulty")
            status = item.get("status") or "draft"
            if status not in {"draft", "active"}: error(start, "status", "must_be_draft_or_active")
            if len(errors) == before:
                result["valid_rows"] += 1
                coverage[year, subject, topic, status] += 1
                if status == "active": result["active_rows_requiring_server_approval"] += 1
            if len(errors) >= MAX_ERRORS: break
        result["coverage"] = [dict(year=k[0], subject=k[1], topic=k[2], status=k[3], count=n)
                              for k, n in sorted(coverage.items())]
    except csv.Error:
        error(parser.line_num or 1, "file", "malformed_csv")
    if result["rows_checked"] == 0 and not errors: error(1, "file", "no_questions")
    result["valid"] = not errors
    return result


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv_file", type=Path)
    parser.add_argument("--taxonomy", type=Path, required=True)
    parser.add_argument("--existing-ids", type=Path, help="JSON list of current IDs; conflicts require revision review.")
    args = parser.parse_args(argv)
    try:
        # Bound reads before decode/parsing. Never echo raw private content on failure.
        with args.csv_file.open("rb") as stream: data = stream.read(MAX_BYTES + 1)
        with args.taxonomy.open("rb") as stream: raw = stream.read(MAX_BYTES + 1)
        if len(raw) > MAX_BYTES: raise ValueError("Taxonomy too large.")
        taxonomy = json.loads(raw)
        existing = []
        if args.existing_ids:
            with args.existing_ids.open("rb") as stream: raw = stream.read(MAX_BYTES + 1)
            if len(raw) > MAX_BYTES: raise ValueError("ID inventory too large.")
            existing = json.loads(raw)
            if not isinstance(existing, list) or any(not isinstance(x, str) for x in existing): raise ValueError("Invalid ID inventory.")
        report = preflight(data, taxonomy, existing)
    except (OSError, ValueError, TypeError):
        print(json.dumps({"valid": False, "error": "input_or_taxonomy_unavailable", "published": False}), file=sys.stderr)
        return 2
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
