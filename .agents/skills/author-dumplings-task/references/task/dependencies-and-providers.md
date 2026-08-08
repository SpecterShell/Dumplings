# Task dependencies and shared providers

## 6. Share Vendor Data Explicitly

Use a `SimpleTask` whose name begins with `#` when at least three package tasks would fetch the same upstream source. With one or two consumers, keep retrieval in the package tasks instead of adding a provider. Store normalized, preferably immutable data in `$Global:DumplingsStorage` and declare the provider in every consumer:

```yaml
Type: PackageTask
DependsOn:
- '#Vendor'
WinGetIdentifier: Vendor.Package
Skip: false
```

`#Argente` fetches architecture-specific catalogs once for the `Argente.*` tasks. `#JetBrains` batches product/channel API requests into one shared catalog. Core includes declared dependencies, waits for them, and blocks consumers when a provider fails. Shared storage does not create an implicit dependency. Sharing a publisher alone is insufficient; the tasks must reuse the same source response or source catalog.
