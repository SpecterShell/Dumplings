# InstallShield prerequisite internals

[Back to InstallShield internals](overview.md).

InstallShield setup prerequisites are small installation packages that run before or alongside the main product. A `.prq` file describes one prerequisite; release configuration, MSI tables, feature mappings, or Advanced UI parcels decide whether a setup selects it.

## Prerequisite architecture

```text
prerequisite definition (.prq)
  -> identity and description
  -> payload files and download locations
  -> detection conditions
  -> supported operating-system conditions
  -> executable and command lines
  -> reboot and privilege behavior
  -> dependencies on other prerequisite definitions

release/package reference
  -> selects one definition by identity/name
  -> can attach it to the setup or one feature

runtime
  -> evaluate OS and detection conditions
  -> acquire payload if needed
  -> launch command line at the required privilege
  -> interpret exit/reboot behavior
```

The definition and reference are separate so the builder can keep a repository of prerequisites while emitting only those selected for one release.

## PRQ XML structure

A prerequisite definition has a `SetupPrereq` root and these principal records:

```text
SetupPrereq
+-- properties
|   +-- Id
|   +-- Description
|   `-- AltPrqURL
+-- files
|   `-- file
|       +-- LocalFile
|       +-- URL
|       +-- CheckSum
|       `-- FileSize
+-- conditions
|   `-- condition ...
+-- operatingsystemconditions
|   `-- operatingsystemcondition ...
+-- execute
|   +-- file
|   +-- cmdline
|   +-- cmdlinesilent
|   `-- returncodetoreboot
+-- behavior
|   +-- Reboot
|   +-- Hidden
|   `-- Lua
`-- dependencies
    `-- dependency File="..."
```

Definitions are XML configuration, not payload containers. The referenced files can be staged beside the setup, embedded elsewhere in release media, or fetched from a URL.

## Payload records

Each `files/file` entry supplies a logical local filename and can supply a URL, checksum, and size. `AltPrqURL` can point to an alternate definition rather than the payload itself.

The builder may encode size as a comma-separated value whose final part is the payload byte count. Checksums and URLs are authored data until the runtime or an analyzer verifies the actual file.

## Detection conditions

Prerequisite detection answers whether installation is already satisfied. Conditions can inspect files, versions, registry values, products, and platform state. Operating-system conditions restrict which targets should evaluate or run the prerequisite.

Condition trees can contain boolean groups and comparisons. Results depend on the target machine and can differ between architecture, Windows version, and installed runtime state.

The runtime should skip an already satisfied prerequisite. Failure to evaluate or an authored mismatch can instead block the setup, show UI, or follow the definition's behavior.

## Invocation

The `execute` record identifies one payload and two command-line forms:

- `cmdline` for ordinary or interactive installation.
- `cmdlinesilent` for setup's silent chain.

If `cmdlinesilent` is absent, running the outer setup silently does not make the child package silent. Depending on runtime policy, setup can prompt, skip, or fail.

`returncodetoreboot` lists codes that request a reboot. The outer setup can aggregate that request with its own completion behavior.

## Privilege behavior

The Prerequisite Editor stores limited-user compatibility in `behavior/@Lua`. In supported definitions:

```text
Lua="1"       -> prerequisite is marked compatible with limited users
Lua omitted   -> editor default requires administrative privileges
```

This setting belongs to the child prerequisite. It does not establish the scope of the main product.

If the outer setup is silent and unelevated, a missing prerequisite that requires administrative rights can create a difficult boundary: the child cannot show or complete UAC interaction, or the launcher can terminate rather than continue an incomplete installation. Starting the outer setup elevated avoids that boundary for some packages, but it cannot supply a missing silent command line.

## Reference locations

Prerequisites can be selected from several structures:

| Structure | Meaning |
| --- | --- |
| `Setup.ini [ISSetupPrerequisites]` | Release-level prerequisite list for the launcher. |
| MSI `ISSetupPrerequisites` | InstallShield-authored prerequisite references and ordering. |
| MSI `ISFeatureSetupPrerequisites` | Prerequisite attached to a specific MSI feature. |
| Advanced UI `Prq` or `Prerequisite` parcel | Suite package with its own selection and eligibility conditions. |
| `.prq` dependency element | One prerequisite definition depends on another definition file. |

Presence of a `.prq` on disk is not a reference. InstallShield installations and builder repositories commonly contain definitions unused by the selected release.

## Correlation

A release reference can use an ID, description, filename, or filename stem. Correlation should remain exact because similarly named definitions often represent different runtime versions, languages, or architectures.

An ambiguous reference cannot safely inherit payload URLs or silent command lines from one candidate. A missing definition still proves that the release expects a prerequisite, but its detailed behavior remains unavailable.

## Advanced UI prerequisites

Suite prerequisite parcels participate in package eligibility, selections, transactions, detection, and operation planning. The suite can stage a `.prq`, embed its payload, or use a URL. An eligible parcel is not necessarily executed: installed-state detection and suite operation selection still apply.

## Elevation and silent installation

Several privilege signals must remain separate:

- Outer PE `requestedExecutionLevel`.
- Prerequisite `Lua` behavior.
- Nested MSI elevation behavior.
- Advanced UI parcel `Elevation` property.
- Script-launched child process behavior.

Machine scope does not prove that Setup.exe requests elevation. Conversely, an administrative prerequisite can require elevation even when the main product is otherwise user-scoped.

Windows Installer quiet and passive modes also differ. Quiet mode cannot present normal UAC UI. Passive mode can show elevation, but an InstallScript MSI can still display its own interactive window or require that `msiexec` started from an elevated process.

## ARP and dependency implications

A prerequisite can install a separate product with its own ARP entry. The main setup may leave it installed during uninstall because other products can share it. This is different from an embedded nested MSI whose ARP entry is hidden and owned only as part of the parent chain.

An InstallShield prerequisite is not automatically a WinGet dependency. Static analysis must determine whether the release selects it, whether target detection can skip it, and whether an equivalent package dependency is appropriate.

## Static-analysis boundaries

The following values depend on runtime state:

- Whether a detection condition is satisfied.
- Whether a feature-selected prerequisite is active.
- Whether a URL payload remains available.
- Whether UAC can be shown or accepted.
- Child installer exit and reboot behavior.
- Whether an absent silent command line causes UI, skip, or failure.

Preserve definition and reference evidence separately so these questions can be resolved without attributing an unused prerequisite to the release.

## Sources

See the Prerequisite Editor, administrative-privilege, and execution-level references collected in [the overview](overview.md#source-references).
