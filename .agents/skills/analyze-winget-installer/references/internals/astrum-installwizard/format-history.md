# Astrum InstallWizard format history

Astrum release identity and parser route are separate. Product version resources and application versions are author-controlled. The parser selects a route from footer length, trailer framing, self pointers, protected configuration, catalog boundaries, and record widths.

## Verified sequence

| Structural profile | Verified builder media | Footer | File record | Distinguishing behavior |
| --- | --- | --- | --- | --- |
| `Legacy1` | 1.80, 1.83, 1.84, 1.90, 1.91.02, 1.91.51, 1.94, 1.95.4, 1.95.5 | `0xE8` | 60 bytes | legacy identity, no record conditions, no post-interactive table, opaque option tail |
| `Early2` | 2.01.50, 2.02.50, 2.04.20 | `0xEC` | 64 bytes | 2.x conditions and advanced resources with legacy identity framing |
| `Modern2` | 2.21.20, 2.22.30, 2.23.20, 2.24.00, 2.29.00, 2.29.50 | `0xEC` | 64 bytes | leading runtime word, duplicate internal identity fields, modern uninstaller fields, sparse option offsets |

The exact `Early2` to `Modern2` release boundary is not known because no cached fixture covers 2.04.20 through 2.21.20. A 2.x configuration selects `Modern2` only when the word at the fixed-metadata boundary satisfies the catalogued structural range; otherwise it follows `Early2`.

## Trailer evolution

Astrum 1.80 has the legacy no-magic ending. The 1.95.5 capture is the first available 1.x artifact with the later dual trailer magic, but availability does not prove that release introduced it. Both endings still select the `astrum-1` footer and `Legacy1` configuration route.

All verified 2.x media uses the dual-magic ending and the `astrum-2` footer. Later signed media places the PE certificate table after that logical ending. The security-directory file offset therefore bounds trailer search; a certificate is never scanned as configuration or payload data.

## Command-line history

Archived version history says silent installation was introduced in Astrum 1.22. The compiled overlay does not preserve a trustworthy builder subversion independent of application metadata. Verified 1.80 through 1.95.5 runtimes contain a delimited `/SILENT` token in the native PE command-line table, and the parser uses that exact token as support evidence. A 1.x runtime without the token remains unresolved.

Astrum 2.x builder help documents `/silent`, `/AcceptLicense`, and success exit code `1`. `Early2` keeps the published claim that a User Information dialog blocks silent installation because no contradictory runtime test exists for that profile. Controlled 2.29.50 `Modern2` media proves the runtime skips the dialog under `/silent`, so a compiled dialog does not disable silent mode for that profile.

## Structural compatibility policy

Observed release ranges document coverage; they are not allowlists. A future or intermediate setup may parse when every invariant of an existing route validates. A setup with a new footer length, record width, configuration discriminator, or catalog relationship must be rejected or represented by a new format-catalog entry. The parser must not select the nearest release by a version string.

## Uncovered releases

No structurally distinct artifact before 1.80 or after 2.29.50 is currently available. Astrum 1.x spanned output is also absent. These are fixture gaps, not permission to generalize the 2.x logical-stream reconstruction or assign unknown footer fields.
