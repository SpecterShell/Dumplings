# MicaSetup metadata model

## Generated configuration

MicaSetup v1.0 configures `MicaSetup.Core.Pack` through `UsePack(Action<Pack>)`. Later releases configure an Option object through a transitional `UsePack` host or `UseOptions(Action<Option>)`. MakeMica emits a dense sequence of setter calls in a generated lambda.

```text
Hosting.CreateBuilder()
  -> UseElevated(bool? requested)
  -> UsePack(Action<Pack>) or UseOptions(Action<Option>)
       -> ldarg Pack/Option
       -> constant, option reference, or supported expression
       -> callvirt Pack/Option::set_Property(value)
       -> repeat
```

The parser locates a high-density initializer instead of accepting isolated option-like strings. This prevents runtime implementation setters from being mistaken for package configuration.

## Symbolic CIL subset

The bounded evaluator supports literal strings and numeric values, booleans, null, nullable booleans, local loads and stores, compiler-emitted string arrays, official `CloseApplicationInfo` object initializers, option-property getters, string concatenation, `String.Format`, interpolation lowered to supported calls, and branches whose conditions resolve from known values. Every assignment records its defining method and CIL offset.

Unknown calls, reflection, delegates with arbitrary bodies, unsupported object graphs, cyclic control flow, malformed method bodies, and branches depending on runtime state are not executed. `UnresolvedExpressions` retains the property name, reconstructed bounded call expression with literal and option-reference arguments, defining method, and IL offset. Runtime-localized `SetupName`, `MessageOfPage2`, and `MessageOfPage3` calls are informational UI evidence; unresolved expressions that can change package metadata or installation behavior retain an incomplete diagnostic with the affected manifest fields.

## Option normalization

Legacy Pack and Option names are normalized to the shared public model. The historical `IsCrateAsAutoRun` spelling maps to `IsCreateAsAutoRun`. `OptionValues` contains resolved public values; `OptionEvidence` contains source locations and resolution state. `UnpackingPassword` is always redacted from both.

| Option group | Result evidence |
| --- | --- |
| `AppName`, `DisplayName`, `DisplayVersion`, `Publisher`, `KeyName`, `ExeName`, `DisplayIcon` | package and ARP metadata |
| `UseElevated`, request execution level, path preferences | scope and default installation location |
| `IsCreateRegistryKeys`, `SystemComponent`, `IsUseRegistryPreferX86` | ARP gate, visibility, and registry view |
| shortcut and autorun booleans | `Shortcuts` and `AutorunEntries` |
| firewall, certificate, PATH, ACL, Explorer, delayed-delete booleans | typed system-effect collections |
| overlay extensions, patterns, and handler | `OverlayCleanup` plus unresolved custom-handler evidence |
| `CloseApplications` | resolved official close records or unresolved object evidence |
| language and license options | `SupportedLanguages` and `LicensePolicy` |

## Registry evidence

The parser projects direct `Microsoft.Win32.Registry.SetValue` calls only when key, value name, value, and optional value kind are literal or symbolically resolved. Those writes feed the shared association interpreter. Protocols require a class key with `URL Protocol` and a literal open command. File extensions require a literal extension-to-ProgID relationship.

`RegistryKey` object flows are not equivalent to static `Registry.SetValue` calls. Calls such as `OpenSubKey`, `CreateSubKey`, instance `SetValue`, conditional key selection, or helper wrappers require object-state and control-flow emulation. They remain unresolved rather than being converted into incomplete registry writes.

## System-effect ownership

Built-in options can prove intended shortcuts, autorun, PATH changes, firewall allowances, certificate installation, ACL changes, overlay cleanup, Explorer refresh, and delayed deletion. Some effects execute only when elevated. The result records this condition rather than claiming that a user-mode setup performed the change.

Official `CloseApplicationInfo` initializers expose target, description, window title, graceful-close policy, reboot prompt, forced termination, and timeout. Computed constructors, callbacks, and custom types remain unresolved. Application first-run behavior is outside the setup model and requires installed-state comparison.
