# dotNetInstaller uninstaller and ARP behavior

## Ownership rule

dotNetInstaller normally orchestrates other installers and does not create the final visible Apps & Features entry itself. The selected nested component is the owner. ProductCode, UpgradeCode, display metadata, scope, and visibility must therefore come from that component or installed-state evidence.

## Nested MSI projection

The parser resolves configured MSI commands to embedded cabinet files or explicit companions and parses each distinct physical MSI once. It returns ProductCode, UpgradeCode, display metadata, scope, install-location property, MSI versus WiX evidence, ARP visibility, architecture, registry associations, and every configuration/component occurrence that selects the MSI.

If one distinct visible MSI exists, its identity can be projected to the wrapper. A hidden MSI keeps its ProductCode as nested evidence but does not create a visible `AppsAndFeaturesEntries` row. Multiple distinct MSIs require selection for the target installer entry.

## Selection grammar

`Get-DotNetInstallerNestedMsiSelection` applies configuration and component architecture filters together with LCID filters. Positive lists are OR sets. Fully negated lists exclude matching values. Mixed positive and negated tokens are invalid, matching the runtime. No match and several matches remain explicit outcomes; the function never returns the first MSI merely because it appears first.

## Non-MSI components

Nested EXE, CMD, open-file, MSP, and MSU components can install products or write registry state, but dotNetInstaller configuration does not prove their final ARP identity. Use the corresponding nested parser where bytes are available. Use VM installed-state comparison when custom commands, downloads, or target-state conditions own registration.

## Wrapper uninstall behavior

Install configurations can enable uninstall and provide mode-specific uninstall commands for each component. The runtime uses the same full/basic/silent fallback as installation. This orchestration does not create a stable wrapper ProductCode. Uninstall support, optional-component prompts, and installed checks can change which child routes execute.

## Manifest guidance

Author the selected nested ProductCode at installer level only when its route matches the manifest architecture and locale. Include Apps & Features overrides only for values that differ from the default locale or effective installer type. Do not combine ProductCodes from mutually exclusive configurations into one installer entry.

