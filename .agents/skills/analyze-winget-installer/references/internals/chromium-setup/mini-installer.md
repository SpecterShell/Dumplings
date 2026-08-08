# Chromium mini-installer internals

[Back to Chromium Setup parser internals](overview.md).

## Binary structure

The mini-installer stores the setup executable and product archive in PE resources. Resource names and IDs are resource-relative.

```text
Chromium mini-installer PE
+-- B7 setup*.7z                   preferred compressed setup resource
+-- BL setup.ex_                   compressed setup fallback
+-- BN setup.exe                   uncompressed setup fallback
`-- B7/BN product archive          chrome.7z or vendor equivalent
```

Current setup executables also expose a contiguous `kInstallModes` array. PE32+ records are 232 bytes; PE32 records are 168 bytes.

```text
InstallConstants identity prefix (PE32+; PE32 uses 4-byte pointers)
Offset  Size  Field
------  ----  -----------------------------------------------
0x00       8  sizeof(InstallConstants), size_t = 232
0x08       4  mode index; primary mode must be 0
0x0C       4  alignment padding
0x10       8  -> install_switch, ASCII
0x18       8  -> install_suffix, UTF-16LE
0x20       8  -> logo_suffix, UTF-16LE
0x28       8  -> updater app_guid, UTF-16LE
0x30       8  -> base_app_name, UTF-16LE
0x38       8  -> base_app_id, UTF-16LE
0x40       8  -> browser ProgID prefix, UTF-16LE
0x48       8  -> browser description, UTF-16LE
0x50       8  -> direct-launch URL scheme, ASCII
...           remaining GUID, channel, icon, and sandbox fields
0xE8          next contiguous mode record
```

## Parsing behavior

Apply the source-defined setup precedence `B7`, then `BL`, then `BN`. Decode only the selected setup resource, then parse linked `InstallConstants` records through mapped PE pointers rather than searching arbitrary product strings.

## Metadata projection

Use the selected install mode for product identity, channel, application GUID, ProgID, and protocol evidence. Report the product archive and selected setup resource separately so nested execution remains distinct from physical adjacency.

## Limits and gaps

Every pointer must resolve through a mapped PE section, strings must satisfy their field encoding, and mode indexes must be contiguous. Reject tied but different candidate arrays. Vendor forks without a source-compatible resource or identity layout remain unresolved evidence.
