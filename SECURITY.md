# Security policy

## Supported versions

Open Spotlight has no supported public release yet. Security fixes currently
target the active development branch. This file will list supported versions
when signed releases exist.

## Reporting a vulnerability

Do not disclose suspected vulnerabilities in a public issue. Before publication,
the repository owner must enable GitHub private vulnerability reporting and add
a monitored security contact. Until that gate is complete, coordinate privately
with the repository owner.

Include the affected commit or build, reproduction steps, expected impact, and
whether the report involves local files, provider credentials, subprocesses,
prompt injection, indexing scope, or update/signing behavior. Do not include real
credentials or unrelated personal data.

## Current security boundary

The project uses approved-root validation, scope filtering, explicit provider
actions, attachment disclosure, sanitized subprocess environments, isolated
working directories, and provider-specific restrictions. These controls are
defense in depth; the development build is not a hardened OS sandbox and is not
ready for hostile multi-user deployment.
