# dotNetInstaller metadata model

## Root document

The root element is `configurations`. It contains optional schema and file-attribute records plus install and reference configurations. Current documents keep mixed child records in authored order. Historical documents may group components, embedded files, and downloads under plural container elements.

```text
configurations
+-- schema
+-- fileattributes
+-- configuration type="install"
|   +-- component
|   +-- embedfile or embedfolder
|   +-- downloaddialog and download records
|   +-- installed checks and controls
|   `-- complete_command[_basic|_silent]
`-- configuration type="reference"
    +-- configfile filename="..."
    `-- download metadata
```

## Configuration records

An install configuration can filter on LCID and OS ranges, require administrator rights, enable install or uninstall, configure logging, control reboot behavior, select UI strings, and contain component and completion routes. A reference configuration names another XML document and can include download evidence for that document.

The parser stores each document with its path, depth, and primary or reference status. It assigns stable configuration indices across the resolved graph. Missing, ambiguous, cyclic, over-depth, and schema-conflicting references remain diagnostics and unresolved evidence.

## Components

Supported component types are `msi`, `msp`, `msu`, `exe`, `cmd`, and `openfile`. Common fields include ID, display name, required or selected state, architecture and locale filters, installed checks, embedded files, download records, reboot policy, and error policy.

| Current attribute | Historical fallback |
| --- | --- |
| `display_name` | `description` |
| `required_install` | `required` |
| `selected_install` | `selected` |
| `lcid_filter` | `lcid` |
| `os_filter_min` and `os_filter_max` | `os_filter_greater` and `os_filter_smaller` retained separately |

Missing component IDs fall back to the resolved display name. Cabinet keys use the normalized final ID.

## Command model

The parser returns full, basic, and silent command candidates, the selected source attribute for each mode, whether fallback occurred, the resolved payload reference, candidate matches, working directory, and unattended proof.

MSI, MSP, and MSU records are projected into their `msiexec.exe` or `wusa.exe` forms. EXE records retain executable, parameters, response-file and install-directory fields. CMD and open-file records remain explicit arbitrary command evidence.

## Path resolution

`#CABPATH` resolves only against the owning component's cabinet namespace plus global files. Other path variables resolve only against explicit companion files. Matching order is exact logical path, resolved host-path suffix, then unique basename. Duplicate basenames remain ambiguous.

## Conditions and controls

Configuration and component architecture and LCID filters are deterministic. File, directory, registry, WMI, OS, and installed-product state are target-machine inputs. Product checks receive a focused projection, but they do not become the package ProductCode. UI controls are returned as typed attribute trees rather than executed.
