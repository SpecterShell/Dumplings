# dotNetInstaller binary format

## PE resource map

All offsets returned by the PE reader are absolute file offsets. Resource sizes are bounded by the PE resource directory and do not include adjacent resource padding.

```text
PE image
+-- DOS header: MZ and e_lfanew
+-- PE/COFF headers and sections
+-- non-resource sections
|   `-- native runtime and null-terminated option tokens
`-- .rsrc tree
    +-- CUSTOM / RES_CONFIGURATION
    +-- CUSTOM / RES_CAB_LIST
    +-- CUSTOM / RES_BANNER
    +-- CUSTOM / RES_SPLASH
    +-- HTM / <name>
    `-- RES_CAB / <part-name>
```

`RES_CONFIGURATION` contains XML bytes. InstallerLinker emits UTF-8. BOM-marked UTF-16 is accepted for historical or hand-authored configurations. Exactly one configuration resource is required for normal packaged detection.

`RES_CAB_LIST` is UTF-16 display text. Upstream truncates it when the list grows too large, so it is never the extraction catalog.

## Cabinet resource names

```text
SETUP_<part>[.CAB]                  global cabinet set
SETUP_<normalized-id>_<part>[.CAB] component cabinet set
```

The component key is the uppercase component ID with every non-ASCII-alphanumeric character replaced by `_`. The part number is one-based. Each set must start at part 1 and remain contiguous.

## Cabinet bytes

Each resource contains one complete or continued Microsoft Cabinet volume.

```text
Offset  Size  Field
------  ----  ----------------------------------------------
0x00       4  signature 4D 53 43 46 ("MSCF")
0x04       4  reserved
0x08       4  cabinet size, UInt32 LE
0x0C       4  reserved
0x10       4  file-table offset, UInt32 LE
0x14       4  reserved
0x18       1  minor version
0x19       1  major version
0x1A       2  folder count, UInt16 LE
0x1C       2  file count, UInt16 LE
0x1E       2  flags, UInt16 LE
0x20       2  set ID, UInt16 LE
0x22       2  cabinet index, UInt16 LE
```

Continuation names in the cabinet header refer to staged filenames. Extensionless PE resources are therefore staged with `.CAB` names before the shared cabinet reader follows the set.

## Logical ownership

Physical adjacency does not imply component ownership. The resource name selects a logical cabinet set, and XML `embedfile` or `embedfolder` records map files from that set into a component route. A global file can be referenced by several components. Repeated references to one nested MSI do not create several physical MSI products.

## Configuration-only and signed media

A PE without `RES_CAB` can still be dotNetInstaller when it has a valid configuration resource or an explicitly supplied configuration plus compiled runtime evidence. Its payload references can point to downloads or adjacent files. The parser reports those references but cannot extract absent bytes.

Authenticode data belongs to the PE certificate table and is outside mapped sections. Resource offsets remain authoritative. The parser does not scan certificate bytes or trailing data for a second cabinet route.

