# Privacy and data flow

This document describes the current development build. It is a technical notice,
not a final legal privacy policy.

## Data kept on the Mac

Open Spotlight stores preferences and launcher history in macOS user defaults.
For folders the user explicitly selects, the early local index stores file paths,
titles, modification dates, extracted text chunks, FTS rows, and Apple
NaturalLanguage sentence embeddings in SQLite under Application Support.

The app does not currently include telemetry, analytics, crash reporting, cloud
sync, or an Open Spotlight account.

## Data sent to providers

Normal app search, file search, indexed retrieval, settings, and local actions do
not invoke an AI provider. A provider is invoked only through an explicit AI
action.

A manually attached text file is included only after the launcher displays its
file name, byte count, extracted character count, and destination provider, and
the user confirms the disclosure. Indexed search results are not yet included in
provider prompts.

The selected CLI is a separate vendor application. Its vendor controls remote
processing, retention, account policy, and subscription eligibility.

## Credentials

Open Spotlight probes provider executables and authentication state but does not
extract or persist provider tokens. Authentication is completed through the
provider CLI's own login command. Grok runs with an isolated home and a reference
to the user's existing Grok authentication file.

## Deletion boundary

The current Settings surface can clear indexed rows for approved roots. Complete
release-grade deletion of SQLite, WAL and SHM files, bookmarks, quarantined
generations, embeddings, caches, history, and trust decisions remains a public
beta gate and must not yet be claimed.
