# Regression and performance tools

`Invoke-Regression.ps1 -Component Core|PackageModule|InstallerParsers -Offline` runs synthetic/offline test groups and writes NUnit XML under `Outputs/Tests`. Parser suites select explicit `Unit` tags and exclude `RealFixture` cases. An empty temporary fixture root is used unless an explicit root is supplied; fixture-guarded cases skip. The fixture helper rejects missing fixtures before attempting a download when `DUMPLINGS_TEST_OFFLINE=1`. Running without `-Offline` enables the component's full suite and its existing fixture policy. Neither mode enables live tests tagged `Live`.

The separate GitHub Actions regression workflow uses isolated Windows jobs and pinned runtime and test-module caches. It has read-only repository permissions, no task invocation, no secrets, and no submission or message step. Test dependencies are pinned in `Modules.psd1`; runtime dependencies remain in the root `PowerShellModules.psd1`.

## Benchmarking

```powershell
./Utilities/Testing/Measure-Dumplings.ps1 -Samples 3 -OutputPath ./Outputs/after.json
./Utilities/Testing/Measure-Dumplings.ps1 -RepositoryPath C:/Checkouts/Dumplings-Before -Scenario Independent,Dependencies -Samples 3 -OutputPath ./Outputs/before.json
./Utilities/Testing/Measure-Dumplings.ps1 -Scenario Parser -InstallerPath C:/Fixtures/setup.exe -ParserCommand Get-CreateInstallInfo -Samples 3
```

Every sample runs in a fresh PowerShell process. Synthetic task roots contain no real task state and invoke no external services. The manifest workload uses supplied hashes and disables installer analysis; the parser workload is static. The harness deletes its own temporary directories after recording elapsed milliseconds and peak process working set. Compare medians from repeated runs on an otherwise idle machine. These measurements include module startup and are not CI timing thresholds or whole-machine memory measurements.

The dependency workload includes a slow provider, six consumers and a separate fast-provider chain. This tests whether blocked consumers delay work whose dependencies have already completed. Every sample asserts that all 17 tasks actually succeeded before accepting its timing.

### Initial measurements

Three isolated samples per case on September 22, 2026, repeated after the fixture suites finished, produced these median elapsed times. They measure synthetic graphs on one host, not production-network workloads.

| Synthetic workload | Workers | Before | After |
| --- | --- | --- | --- |
| Independent tasks | 1 | 2.904 s | 3.087 s |
| Independent tasks | 4 | 1.679 s | 1.661 s |
| Dependency graph | 1 | 2.908 s | 3.104 s |
| Dependency graph | 4 | 2.433 s | 1.984 s |

The ready scheduler shortened the dependency-heavy four-worker case by about 18%. Initial C# compilation added about 0.2 seconds and 60 MiB to these small Core-only processes. The scheduler is retained for dependency readiness and terminal-state correctness; independent startup has not improved. Normal PackageModule runs already compile managed infrastructure, so the Core-only memory difference should not be extrapolated to complete automation runs.

`Get-TaskMechanicsInventory.ps1` groups repeated AST command/parameter shapes and reports task names and source line numbers. It neither prints argument values nor changes scripts. Review actual request headers, authentication and freshness requirements before sharing a publisher fetch; similar command shapes alone do not justify a provider task.

Use `Get-TaskMechanicsInventory.ps1 -InstallerTracking` to inventory direct legacy validator-state access and migrated `CheckInstallerUpdates` calls. Matches require source review; computed property access can be missed. `Amazon.EC2Launch` is explicitly deferred because it transitions to versioned URLs. The eight migrated scripts have an offline integration suite that supplies synthetic headers, bytes, versions, extraction results and release notes; it runs the scripts only with write/message/submission gates disabled and does not invoke an external extractor.
