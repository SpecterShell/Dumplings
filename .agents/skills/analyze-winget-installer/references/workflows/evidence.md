# Transient evidence workflow

Persist large source, parser, VM, and validation records so later work can inspect them without relying on conversation history.

## Directory layout

Create one UTC-stamped run directory under the gitignored `Sandbox` tree:

```text
Sandbox/Evidence/<PackageIdentifier>/<UTC-run-id>/
+-- summary.md
+-- source/
+-- installer/
+-- vm/
`-- manifest/
```

Use a sortable UTC run ID such as `20260808T143000Z`. Do not move or delete existing user-owned `VMValidation` data.

## What to store

- `source/`: raw human-readable source responses, selected safe headers, feed bodies, redirects, and source-selection notes.
- `installer/`: hashes, complete analyzer and parser JSON, extraction catalogs, selected payload evidence, and relevant command output.
- `vm/`: before/after snapshots, compact comparisons, tested command lines, elevation context, exit codes, screenshots references, and outcomes.
- `manifest/`: authored YAML, formatter output, and structured validation diagnostics.

Keep browser screenshots in their existing transient output location and record their absolute paths in `summary.md`.

## Summary contract

Keep `summary.md` short. Record official source URLs, installer hashes, detected family, selected payload, manifest decisions, unresolved warnings, VM outcome, and paths to detailed evidence. Do not paste complete parser objects or registry snapshots into the summary or conversation.

Never persist tokens, authorization headers, cookies, credentials, or unredacted signed URLs. Redact secrets before writing captured traffic.

## Reading evidence later

Report the run path and a short result in chat. In later turns, query only the needed fields with `rg`, `Select-String`, or a targeted `ConvertFrom-Json` projection. Avoid rereading complete records after context compaction.
