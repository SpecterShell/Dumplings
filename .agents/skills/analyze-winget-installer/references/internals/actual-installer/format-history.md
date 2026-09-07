# Actual Installer format history

## Route selection principle

Actual Installer routes are selected from the validated physical container sequence. The builder version then checks whether that sequence is expected for the claimed generation. A conflicting version produces a diagnostic but cannot redirect parsing into a structurally incompatible decoder.

## Verified chronology

| Route | Verified version or artifact | Change established by the fixture |
| --- | --- | --- |
| `Cabinet3` | 3.8 builder installer | `setup.ini` in the first CAB; one later CAB per ordered file row |
| `Cabinet4` | 4.8 builder installer | metadata name changes to `aisetup.ini`; metadata remains first; ARP uses an AppName key and versioned display name |
| `Cabinet5` | 5.2 builder installer | metadata CAB moves to the end; Product GUID based ARP confirmed in VM |
| `Zip6Plus` | 6.6 and 6.7 builder installers | payload storage changes from one-file CABs to decimal-indexed ZIP entries |
| `Zip6Plus` | 8.0, 8.2, 8.3, and 8.4 builder installers | same physical route with later metadata fields and x64/scope behavior |
| `Zip6Plus` | fixed 9.6 builder installer | later fixed-version media remains on the numbered-ZIP route with 43 mapped payloads |
| `Zip6Plus` | Actual Updater 4.8.1 built by 9.2 | separate updater product remains structurally compatible and uses guarded encoded command fields |
| `Zip6Plus` | 9.8 compiled configuration in current 10.0 online wrapper | dynamic version and online behavior remain on the numbered-ZIP route |
| `Zip6Plus` | Actual Updater Free 5.0 | product subtype uses the same structural parser without product hardcoding |
| `ZipExternalData` | documented Setup EXE + Data structure plus synthetic 7z fixture | metadata-only executable route and bounded caller-supplied companion extraction; real 9.6 output is a Zip6Plus hybrid with embedded generated files |

The current format catalog deliberately uses broad major-version compatibility bounds after structural selection. It does not claim that every release within a range has been validated.

## Cabinet3

The 3.8 fixture starts the verified line. The first CAB contains `setup.ini`; following CABs normally contain one payload each. The `[Files]` table uses numeric keys and bare `?` field separators. The visible Apps & Features policy can be recovered, but the supported configuration does not expose a Product GUID, so the uninstall-key identity remains unresolved.

```text
PE -> metadata CAB -> payload CAB 0 -> payload CAB 1 -> ...
```

## Cabinet4

The 4.8 fixture retains metadata-first ordering but renames the configuration to `aisetup.ini`. The payload mapping remains positional. A checkpointed `/S` installation completed with exit code 0 and proved that this pre-GUID runtime uses literal `AppName` as the uninstall-key identity and writes `AppName AppVersion` as the visible display name.

```text
PE -> metadata CAB containing aisetup.ini -> payload CABs
```

## Cabinet5

The 5.2 fixture places payload CABs before the metadata CAB. The real builder setup has 52 logical `[Files]` rows and 51 direct payload CABs. Its unmatched row repeats `<InstallDir>\Uninstall.exe`, which is already supplied by an earlier physical payload record; the parser classifies it as `DuplicateLogicalRecord` and does not shift subsequent cabinets. The metadata `AIUninstall.exe` is byte-identical to the mapped uninstaller in this fixture, but that observation does not prove the later runtime-patching route.

```text
PE -> payload CAB 0 -> ... -> payload CAB 50 -> metadata CAB
```

A checkpointed silent installation of the 5.2 builder confirmed its GUID uninstall key, machine scope, 32-bit registry view, display fields, install location, icon, and uninstall command. This fixture anchors the modern ARP model but does not prove every 5.x project option.

## Zip6Plus

Version 6.x replaces the one-CAB-per-file sequence with one or more standard ZIP ranges. Payload entries use decimal names such as `0`, `1`, and `42`; the metadata ZIP contains `aisetup.ini` and non-payload resources. Central-directory offsets are relative to each embedded ZIP start, so each archive must be independently rebased and bounded.

```text
PE
+-- payload ZIP 0
|   +-- entry 0
|   +-- entry 1
|   `-- central directory and EOCD
+-- optional additional payload ZIPs
`-- metadata ZIP
    +-- aisetup.ini
    +-- language and helper entries
    `-- central directory and EOCD
```

Later builder releases preserve the route while expanding the configuration model. Scope selection, x64 compliance, online variables, and updater products therefore belong to metadata/runtime interpretation rather than a new archive decoder.

## ZipExternalData

Setup EXE + Data is a packaging mode rather than a chronological replacement for `Zip6Plus`. Its executable can retain only the metadata ZIP while `DataFileName` identifies a separately distributed 7z/LZMA archive, but controlled 9.6 builder output retains a numbered payload ZIP for generated uninstaller files and stores application files in the companion archive. The parser therefore keeps physical format generation separate from compiled media mode and expands only a caller-supplied local archive.

The separately distributed `Downloader.exe` has no validated Actual Installer setup container sequence. A shared publisher and product naming are insufficient detection evidence, and the parser rejects it.

## Observed delimiter history

Real `[Files]` rows from 3.8, 4.8, 5.2, 6.6, 8.0, and 9.x configurations use bare `?` separators. This is not limited to the first two cabinet generations. Registry and extension rows use the `*?` separator in observed later media. The parser accepts both forms where the table route permits them, but field meanings remain table- and generation-specific.

## Unsupported chronology

Actual Installer 1.x, 2.x, and releases before the verified 3.8 artifact have no durable structural fixtures in the current corpus. They are rejected rather than treated as Cabinet3. Future media that changes metadata position, container framing, or payload identity also requires a new catalog route.

## Source references

- [Internet Archive captures of the download path](https://web.archive.org/web/*/http://www.actualinstaller.com/download/aisetup.exe)
- [Internet Archive captures of the older root path](https://web.archive.org/web/*/http://www.actualinstaller.com/aisetup.exe)
