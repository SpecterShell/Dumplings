# Updating an existing package PR

## When to use

Use this when a package already exists in the reference repository and its next version is still awaiting review. Updating that PR preserves its number and review history. Normal submission still creates a new PR by default.

## Configuration

Set these keys in `Preference.yaml` or the task's `Config.yaml`:

```yaml
WinGetExistingPackageAction: UpdatePullRequest
WinGetExistingPackageTrustedUsers:
- SpecterShell
- spectopo
WinGetExistingPackageSearchLimit: 30
```

`WinGetExistingPackageAction` accepts `NewPullRequest` and `UpdatePullRequest`. The default, `NewPullRequest`, uses the published reference and the normal submission path without searching for a PR template. `UpdatePullRequest` searches trusted open PRs and uses the selected manifests as the template. If none qualifies, normal new-PR submission continues.

Task values override global preferences. An explicit empty trusted-user list does not inherit global trust and is rejected in update mode. The library defaults to an empty allowlist and a search limit of 30 results per account, with a supported range of 1 through 100. Missing packages continue to use the separate [pending-package settings](pending-packages.md).

## Eligible PRs

The selector accepts one added manifest version of the exact package. That version must be newer than the latest version in the configured reference repository. The PR may also remove one older published version. Every file in that older version must be removed, including all localizations. A base-tree comparison verifies the complete removal.

Modified published files, renames, unrelated changes, multiple additions, multiple removed versions, drafts, closed PRs, and merged PRs are ineligible. An identifier migration uses normal new-PR submission. Keep the reference checkout or fork synchronized before running the task.

The highest eligible manifest version wins, followed by PR update time and PR number for ties. A generated version below the selected version is rejected. Incomplete search results and failed searches are errors. Rejected candidates are logged, and a search with no eligible reference uses the normal submission path.

## In-place behavior

The shared updater checks the captured PR head, complete file delta, and branch permissions. It replaces the unmerged version in one commit and preserves any captured published-version removal. Already deleted files are not deleted a second time. Published files outside the approved removal remain untouched.

`RemoveLastVersion: true` can add removal of the latest published version to an addition-only PR. An unchanged installer URL can request the same removal automatically. If the PR already removes a different version, an explicit removal fails rather than expanding the PR to delete two versions. An inferred removal warns and preserves the existing removal plan. A failed inferred removal read also warns, matching normal submission behavior. The published version must be available on the PR branch before a new removal can be added.

`RemoveLastVersion: false` prevents a new removal. It does not restore files that the selected PR already removes.

The PR title stays a `New version` title when the version is newer than the published reference, even if it equals the selected PR version. Identical content needs no commit, but a stale title can still be repaired. The existing [PR-author credential map](pending-packages.md#pr-author-credentials) applies to title edits. In-place failures do not silently create a replacement PR, and other PRs are not closed by this path.

## Validation

```powershell
.\Core\Index.ps1 -Name Vendor.Package -Force -EnableSubmit -Dry -ThrottleLimit 1
```

Review the selected PR, generated manifests, title, and removal plan before enabling writes. Dry mode performs discovery, generation, and local validation without changing branches or PRs.

`WinGetPendingPackage.psm1` owns the shared selector and updater. `WinGetSubmission.psm1` applies the existing-package policy.
