# InstallBuilder format history

## Route selection principle

InstallBuilder marketing releases, project schema versions, and physical container generations do not have a one-to-one relationship. Select `LegacyMetakit` or `CookFS2` from validated records. Use release history only to constrain feature interpretation and fixture coverage.

## Verified chronology

| Version or boundary | Verified observation | Parser consequence |
| --- | --- | --- |
| 3.6.0 and 3.7.0 | PE/TclKit with Metakit project and payload; no `CFS0002`; project schema 1.2 | `LegacyMetakit` route with stored and zlib `contents:B` extraction |
| Recovered 4.5.3 | Same Metakit-only physical route with a larger VFS and later project vocabulary | No separate container route |
| JXplorer 3.3.1.2 package | CookFS2 with stored and Deflate pages; package version is unrelated to builder release | Third-party proof of CookFS2 and CRC32 page records |
| 7.2.5 builder | CookFS2 with source-backed LZMA record | `CookFS2` route; no new footer or index parser |
| 8.2.0 Enterprise | Two valid Metakit VFS databases plus CookFS2/LZMA | Required-entry VFS ownership; changelog boundary for payload encryption |
| 9.0 | New compression system and LZMA-ultra documented | Interpret handler evidence structurally rather than from version alone |
| 9.5.5 builder | BitRock-branded CookFS2/LZMA | Same physical route with verified LZMA extraction |
| 16.1.0 builder | CookFS2/LZMA and additional action vocabulary | Research coverage without a new container handler |
| 19.5 | Native Windows x64 runtime introduced | Native PE machine can establish 64-bit runtime and registry view |
| 20.2 | VMware branding removed in favor of InstallBuilder | Branding boundary only |
| 23.1.0 builder | Backstaff branding; x86 launcher; CookFS2/LZMA | Same route, later producer identity |
| 26.8.0 x64 builder | Native x64 launcher; CookFS2/LZMA; current project vocabulary | Current route, 64-bit registry view, source-backed metadata and page checks |

## Legacy Metakit generation

InstallBuilder 3.6.0 and 3.7.0 builder installers contain 317 VFS records and project 88 installed payload files below the `origindist` directory. A nominal archived 4.2.0 URL yielded media whose recovered project identifies itself as 4.5.3; that artifact contains 380 VFS records and 107 projected payload files. Record recovered identity rather than trusting an archive filename.

The route stores `project.xml`, `origindist`, `manifest.txt`, Tcl/Tk support files, and application files in one Metakit VFS. Application `contents:B` rows are either stored bytes or RFC 1950 zlib streams. The absence of CookFS is expected and is not a payload error.

Old launchers are commonly UPX-packed and can contain thousands of incidental zlib-looking byte pairs. Candidate scanning is a metadata fallback only. Complete payload parsing starts from the validated Metakit root and schema.

## CookFS2 generation

CookFS2 moves application file data into compressed pages while retaining the compiled project in Metakit. The file index maps logical paths to page numbers, page offsets, sizes, and modification times. Physical component/folder names still require project mapping before they become installed paths.

The same `CFS0002` route spans several product eras and compression choices. Stored, Deflate, BZip2, and the observed unencrypted LZMA handler have distinct page framing but share the footer and index model. A new compression algorithm is not automatically a new container generation.

InstallBuilder 8.2 introduced encrypted payload support. A version at or above this boundary does not prove encryption. Detection requires encrypted/custom handler or project markers. The parser reports encrypted media and requires the project password instead of trying default or harvested passwords.

## Runtime-template evidence

Static extraction of recovered 3.7.0, 4.5.3, 7.2.5, 8.2.0, 9.5.5, 16.1.0, 23.1.0, and 26.8.0 builders produced 15 distinct Windows runtime templates. Builders package these under paths such as `paks/windows*.pak`. Differences include packing, PE bitness, branding, and supported project vocabulary. Generated installers still reduce to the two physical routes documented here.

The builder itself remains a TclKit/Metakit application. Some shipped Tcl files use TclPro bytecode. These files are research evidence about runtime ordering and defaults; they are not parser dependencies and are never evaluated during package analysis.

## Branding history

| Era | Common branding | Parsing rule |
| --- | --- | --- |
| Early releases | BitRock InstallBuilder | Accept only with structural project/container evidence |
| VMware era | VMware InstallBuilder | Treat as the same family; do not create a VMware-specific route |
| 20.2 transition | InstallBuilder | Branding changed without proving a physical format change |
| 23.1 and later observed media | Backstaff InstallBuilder | Keep producer branding separate from package publisher metadata |

The package `vendor` field is the installed application's publisher. It must not be replaced with BitRock, VMware, or Backstaff unless the builder itself is the package being installed.

## Unavailable and misleading historical media

The archived 2.6.1 URL resolves to 3.7.0 media. Available 5.4.15 captures are HTML, replay failures, or redirects to later releases rather than valid distinct installers. These observations do not prove that 2.x or 5.x used unsupported structures. They only mean those versions are not fixture evidence.

Do not add a format-catalog row from a URL label, changelog entry, or MIME type. A historical artifact becomes useful when it has a valid PE, a recoverable project, and a bounded structure that differs from existing routes or confirms a currently unsupported path.

## Extension rule

Add a structural route only when a fixture requires different ownership, framing, offset, compression, integrity, or extraction logic. Add a capability boundary when the physical route remains the same but source or controlled output proves a semantic change. Keep uncertain release mappings as candidates rather than selecting one exact builder version.

## Source references

- [InstallBuilder changelog](https://installbuilder.com/changelog)
- [Archived InstallBuilder 3.7.0 media](https://web.archive.org/web/20060511074856id_/http://www.bitrock.com/installbuilder-3.7.0-windows-installer.exe)
- [Archived nominal 4.2.0 media](https://web.archive.org/web/20070816175458id_/http://www.bitrock.com/installbuilder-enterprise-4.2.0-windows-installer.exe)
- [InstallBuilder releases](https://releases.installbuilder.com/installbuilder/)
