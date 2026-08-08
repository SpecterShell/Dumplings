# MSI builder-detection internals

[Back to MSI and WiX parser internals](overview.md).

## Binary structure

WiX, Advanced Installer, InstallShield, and other builders emit the same Windows Installer database format. Builder identity is therefore table and property evidence rather than a separate file magic.

## Parsing behavior

Combine summary metadata, authored properties, custom actions, table names, directory conventions, and stable builder-specific records. Treat optional product-name strings as fallback evidence only when stronger structured indicators are absent.

## Metadata projection

Return builder classification and its supporting evidence separately from the CFB document type. Do not change an otherwise valid manifest installer type when the builder remains inconclusive.

## Limits and gaps

Preserve `Unknown` when available evidence does not distinguish a builder. Do not reject a valid WiX database merely because one optional marker is absent. Read [MSI static analysis](../../families/msi-wix/analysis.md) for authoring decisions.
