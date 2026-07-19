---
phase: 4
mode: mvp
goal: Retrieve useful, measurable evidence from common user documents
verification: required
---

# Phase 4 Plan - Extraction and hybrid retrieval

## Deliverables

1. Define a sandbox-conscious extractor contract with type detection, limits,
   cancellation, normalized text/metadata, page/sheet/section locations, and
   metadata-only fallback.
2. Implement bounded TXT/Markdown/JSON/CSV, PDFKit PDF, and common DOCX/XLSX/PPTX
   extraction. Treat encrypted, malformed, huge and unsupported files explicitly.
3. Make metadata and FTS searchable immediately; place optional local embeddings
   in a separate versioned queue/table that can be disabled or rebuilt.
4. Parse deterministic filename, date-range, modified/created date, type and root
   filters before retrieval. Fuse filename/metadata/FTS/vector scores with stable
   deduplication and explainable score components.
5. Preserve source location metadata for file, page, section, sheet/cell range or
   chunk offsets.
6. Build a sanitized relevance corpus and expected-result benchmark; include
   lexical, semantic, date/type and mixed queries.

## Acceptance gates

- Known fixture text and locations are extracted correctly for each supported
  format; protected/unsupported files remain metadata-only and never crash work.
- FTS results are usable while embeddings are disabled or incomplete.
- Date/type/root filters return only qualifying documents.
- Retrieval benchmark meets documented Recall@5/MRR targets established before
  tuning and has no denied-root results.
- Rebuilding an embedding version does not block lexical search.

## Verification

Run extractor fixtures, fuzz/malformed inputs, benchmark and disabled-embedding
tests; inspect representative results in the app. Record `04-VERIFICATION.md`,
then run the focused Grok audit.
