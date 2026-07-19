# Bounded Grok Phase Audit

## Purpose

Use Grok only after local verification is green to challenge unsupported
completion claims. Keep the request small enough that one phase consumes little
quota. Grok is read-only and may not modify code, run tools, or expand scope.

## Budget

- One audit per phase; no automatic retry. A second call requires a concrete
  release blocker to have been corrected.
- Maximum input: 1,500 characters.
- Maximum output: 120 tokens.
- Include only acceptance criteria, test/build exit summaries, diff stat, and up
  to five decisive `file:line` excerpts. Never attach the repository or logs.
- Assign every acceptance gate a short ID (`G1`, `G2`, ...). The prompt must
  include every gate ID and its `PASS`/`FAIL` result; only evidence excerpts are
  capped at five. A phase with a failed or omitted gate cannot be submitted.
- If Grok is unavailable or quota-limited, record `NOT RUN`; never fabricate a
  pass. Completion requires a user waiver or a later audit.

## Prompt

```text
You are a read-only release auditor. Check only whether the evidence proves the
phase claims; do not redesign or suggest extras.

PHASE: <number and name>
CLAIMS: <maximum five one-line claims>
GATES: <every gate ID with PASS/FAIL; none may be omitted>
EVIDENCE: <command/result summaries and maximum five file:line excerpts>
KNOWN LIMITATIONS: <short list>

Return exactly one of:
PASS
FAIL\n1. <file:line or missing evidence> - <blocker>  (maximum three)
INSUFFICIENT\n1. <missing evidence>  (maximum three)
No preamble. Maximum 120 tokens.
```

## Evidence record

Append the prompt hash, provider/CLI version, exact response, and disposition to
the phase `NN-VERIFICATION.md`. A Grok `PASS` cannot override a failing machine
gate. A Grok `FAIL` or `INSUFFICIENT` blocks phase completion until corrected,
waived by Pablo, or explicitly carried as a release blocker.
