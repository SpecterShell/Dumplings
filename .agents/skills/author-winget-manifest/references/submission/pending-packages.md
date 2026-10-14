# Packages awaiting their first merge

## When to use

Normal submission requires reference manifests in the configured local checkout or origin repository. If a new package's PR is still awaiting review, opt in to the pending-package fallback. Keep this disabled for ordinary packages and use a narrow, explicitly reviewed author allowlist.

The fallback runs only when no reference version exists. A confirmed remote HTTP 404 can trigger it; authentication errors, rate limits, and transport failures do not count as a missing package. Existing packages keep their current reference and submission policy.

## Configuration

Set these fields in the task's `Config.yaml`:

```yaml
Type: PackageTask
WinGetIdentifier: Vendor.Package
WinGetPendingPackageFallback: true
WinGetPendingPackageTrustedUsers:
- SpecterShell
- spectopo
WinGetPendingPackageAction: UpdatePullRequest
WinGetPendingPackageSearchLimit: 30
```

The same keys are available in `Preference.yaml`. Task values override global values, including `false` to disable the fallback and `[]` to remove inherited trust. Defaults are `false`, an empty trusted-user list, `UpdatePullRequest`, and 30 recent search results per account. The search limit accepts 1 through 100. A truncated search produces a warning; increase the limit when more candidates need review.

`WinGetBlockingPullRequestUsers` remains a separate conflict policy. Trust permits using the selected PR as a reference; it does not exempt every PR from that author from duplicate checks. The selected reference is excluded from those checks because the configured action handles it explicitly.

## Reference selection

Dumplings searches open PR titles for the exact package identifier and configured authors, then inspects their complete changed-file lists. Closed and merged PRs cannot serve as references. Eligible PRs must be non-draft, target the configured upstream branch, and only add recognized manifest files under one version leaf of that package. Deletions, modified files, renames, unrelated changes, multiple versions, and incomplete file lists are rejected. Discovery and pre-write checks reject a PR that has since closed or merged.

The manifest contents supply the version. Selection uses `[WinGetVersion]` to choose the highest valid version among the inspected candidates, then the latest PR update time and highest PR number for ties. A newer-looking title cannot override the file paths or parsed identity. Reference YAML is read at an immutable head SHA, parsed once, and validated locally. A lower generated version is rejected.

Record the selected PR URL, author, version, head SHA, action, and rejected-candidate warnings in the task evidence. Do not add account names merely to bypass a failed submission.

## Update the existing PR

`UpdatePullRequest` is the default action after opt-in. Dumplings preserves the PR number, body, and review history. It rechecks that the PR remains open and unmerged with the captured branch head and addition-only file delta. Manifest changes require push permission to the head repository and are rejected on its default branch.

One guarded commit adds the generated manifests and removes the exact obsolete pending paths. This replacement keeps one version in the PR, regardless of `RemoveLastVersion`, which governs normal repository updates. Concurrent changes cause an error rather than a retry over another author's edits. Identical generated content produces no commit.

The PR title is updated to match the submitted version. Identical manifests still allow a stale title to be repaired without a new commit. A title-update failure stops submission with an explicit partial-success error: the requested manifests remain present, and a rerun retries the title. Missing permissions do not silently switch to a new PR. Grant the required access or explicitly choose `NewPullRequest`.

## PR author credentials

Fork write access can let the bot update a branch without allowing it to rename the author's PR in the upstream repository. An optional `GitHubPullRequestAuthorTokens` map supplies a separate credential for these title edits:

```yaml
GitHubPullRequestAuthorTokens:
  SpecterShell: '<token belonging to SpecterShell>'
```

Supply the map through `Secret.yaml` or the existing `DUMPLINGS_SECRET` Actions secret. Core passes the loaded map to worker runspaces. If both sources provide this key, the file's whole map replaces the environment map. Keep credentials out of `Preference.yaml`, task configuration, logs, and evidence files. Use placeholders in documentation and do not read or edit a user's secret file without explicit authorization.

For a pending PR whose title needs changing, Dumplings matches the rechecked author's login case-insensitively and verifies the selected token through GitHub's authenticated-user endpoint before committing. Empty, malformed, ambiguous, mismatched, or unverifiable configured credentials stop the update without falling back to the bot. A missing map or author entry retains the normal `GH_DUMPLINGS_TOKEN` behavior. An already-current title does not require an author credential.

The selected credential is passed explicitly to the title request. Branch commits, PR discovery, new PRs, and PR closure still use the normal token. The shared environment is never switched between accounts. Token mappings do not replace the trusted-author allowlist or authorize another PR shape.

Identity verification does not prove upstream title-edit permission. Use an author credential with appropriate public-repository access. GitHub currently documents limitations for fine-grained tokens contributing to public repositories outside the user's membership; a classic PAT with `public_repo` scope is the practical option for this case. That scope is broad, so restrict secret access to trusted workflows. A title failure after the commit retains the partial-success error, and diagnostics omit the configured credential and raw credential-bearing exception. See [GitHub token guidance](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).

## Create a separate PR

Set `WinGetPendingPackageAction: NewPullRequest` to use the selected PR's manifests as the template for a separate submission. The new branch starts from the normal origin reference revision, not from the pending head, so it contains only the new package version and does not inherit the old pending version or stack a PR on an unmerged branch.

The new PR body records the source PR, version, and head SHA. The selected PR remains open and is excluded from automatic closure. Decide separately whether to close it after reviewing the new PR. Other duplicate-PR policies remain active. Identical content still preserves the original PR without creating another one.

## Validate before enabling writes

Run the task's ordinary read-only check, then generate the dry manifests:

```powershell
.\Core\Index.ps1 -Name Vendor.Package -Force -EnableSubmit -Dry -ThrottleLimit 1
```

Review `Outputs/WinGet`, the selected reference, installer and locale mappings, and all warnings before enabling real submission. Dry runs perform discovery, generation, and local validation but never update a PR, create a branch, or close a PR.

## Existing-package PR references

Overriding PRs for a package already present in the reference repository is outside this fallback. Such PRs can remove or modify versions. A future workflow should distinguish additions, replacements, and removals, require a separate trust policy, and preview the exact file delta before editing a reviewed branch. Do not enable the missing-package fallback as a substitute for those checks.

## Implementation and API references

`WinGetPendingPackage.psm1` owns selection and in-place replacement. `WinGetSubmission.psm1` chooses the reference and action. `WinGetGitHubRepo.psm1` supplies the [PR API](https://docs.github.com/en/rest/pulls/pulls) and guarded manifest commits.
