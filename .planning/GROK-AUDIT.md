# Grok Phase Audit

## Purpose

Use Grok only after local verification is green to challenge unsupported
completion claims. Keep the request focused and quota-conscious, but never omit
required evidence to satisfy a fixed size or count. Grok is read-only and may
not modify code, run tools, or expand scope.

## Operating policy

- Run the audit only after local verification is green.
- Do not loop automatically. Retry after a concrete blocker has been corrected
  or when Pablo asks for another audit.
- Keep prompts concise by removing repetition, never by dropping a gate, known
  limitation, or decisive evidence.
- Include acceptance criteria, test/build exit summaries, diff stat, and all
  evidence needed to substantiate every gate. Do not attach the whole repository
  or unfiltered logs unless the auditor needs them and Pablo approves.
- Assign every acceptance gate a short ID (`G1`, `G2`, ...). The prompt must
  include every gate ID and its `PASS`/`FAIL` result. A phase with a failed or
  omitted gate cannot be submitted.
- If Grok is unavailable or quota-limited, record `NOT RUN`; never fabricate a
  pass. Completion requires a user waiver or a later audit.

## Prompt

```text
You are a read-only release auditor. Check only whether the evidence proves the
phase claims; do not redesign or suggest extras.

PHASE: <number and name>
CLAIMS: <concise one-line claims>
GATES: <every gate ID with PASS/FAIL; none may be omitted>
EVIDENCE: <command/result summaries and decisive file:line excerpts>
KNOWN LIMITATIONS: <short list>

Return exactly one of:
PASS
FAIL\n1. <file:line or missing evidence> - <blocker>
INSUFFICIENT\n1. <missing evidence>
No preamble. Be concise, but include every blocker or missing item that affects
the verdict.
```

## Evidence record

Append the prompt hash, provider/CLI version, exact response, and disposition to
the phase `NN-VERIFICATION.md`. A Grok `PASS` cannot override a failing machine
gate. A Grok `FAIL` or `INSUFFICIENT` blocks phase completion until corrected,
waived by Pablo, or explicitly carried as a release blocker.
