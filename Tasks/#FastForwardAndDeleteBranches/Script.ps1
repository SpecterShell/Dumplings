$UpstreamRepoOwner = $Global:DumplingsPreference['WinGetUpstreamRepoOwner'] ?? $this.Config['WinGetUpstreamRepoOwner'] ?? 'microsoft'
$UpstreamRepoName = $Global:DumplingsPreference['WinGetUpstreamRepoName'] ?? $this.Config['WinGetUpstreamRepoName'] ?? 'winget-pkgs'
$UpstreamRepoBranch = $Global:DumplingsPreference['WinGetUpstreamRepoBranch'] ?? $this.Config['WinGetUpstreamRepoBranch'] ?? 'master'

if ($Global:DumplingsPreference['WinGetOriginRepoOwner']) {
  $OriginRepoOwner = $Global:DumplingsPreference.WinGetOriginRepoOwner
} elseif (Test-Path -Path 'Env:\GITHUB_ACTIONS') {
  $OriginRepoOwner = $Env:GITHUB_REPOSITORY_OWNER
} else {
  throw 'The WinGet origin repository owner is unset'
}
$OriginRepoName = $Global:DumplingsPreference['WinGetOriginRepoName'] ?? $this.Config['WinGetOriginRepoName'] ?? 'winget-pkgs'
$OriginRepoBranch = $Global:DumplingsPreference['WinGetOriginRepoBranch'] ?? $this.Config['WinGetOriginRepoBranch'] ?? 'master'

#region Delete merged branches
$Branches = @()
$Cursor = $null
for ($i = 0; $i -lt 5 -and $Cursor -and $Object1.data.repository.refs.pageInfo.hasNextPage; $i++) {
  $Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/graphql' -Method Post -Body @{
    query = @"
{
  repository(owner: "${OriginRepoOwner}", name: "${OriginRepoName}") {
    refs(
      refPrefix: "refs/heads/"
      orderBy: { field: TAG_COMMIT_DATE, direction: DESC }
      first: 100
      after: "$($Cursor ?? 'null')"
    ) {
      nodes {
        name
        associatedPullRequests(
          states: [MERGED]
          orderBy: { field: CREATED_AT, direction: DESC }
          first: 100
        ) {
          nodes {
            number
            state
            title
            url
          }
        }
      }
      pageInfo {
        endCursor
        hasNextPage
      }
    }
  }
}
"@
  }
  $Branches += $Object1.data.repository.refs.nodes.Where({ $_.associatedPullRequests.nodes.Count -gt 0 -and $_.associatedPullRequests.nodes[0].state -eq 'MERGED' })
  $Cursor = $Object1.data.repository.refs.pageInfo.endCursor
}

$this.Log("$($Branches.Count) branch(es) in the repo ${OriginRepoOwner}/${OriginRepoName} have been merged. Deleting...")
foreach ($Branch in $Branches) {
  try {
    $this.Log("Deleting the branch $($Branch.name). Merged in:")
    foreach ($PullRequest in $Branch.associatedPullRequests.nodes) {
      $this.Log("  [$($PullRequest.state)] #$($PullRequest.number) - $($PullRequest.title) - $($PullRequest.url)")
    }
    $null = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginRepoOwner}/${OriginRepoName}/git/refs/heads/$($Branch.name)" -Method Delete
  } catch {
    $this.Log("Failed to delete the branch $($Branch.name): ${_}", 'Warning')
    $_ | Out-Host
  }
}
#endregion

#region Fast-forward
$this.Log("Updating the branch ${OriginRepoOwner}/${OriginRepoName}/${OriginRepoBranch} to ${UpstreamRepoOwner}/${UpstreamRepoName}/${UpstreamRepoBranch}")

try {
  $null = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginRepoOwner}/${OriginRepoName}/git/refs/heads/${OriginRepoBranch}" -Method Patch -Body @{
    sha = $Global:DumplingsStorage['UpstreamSha'] ??= (Invoke-GitHubApi -Uri "https://api.github.com/repos/${UpstreamRepoOwner}/${UpstreamRepoName}/git/ref/heads/${UpstreamRepoBranch}").object.sha
  }
} catch {
  $this.Log("Failed to update the branch: ${_}", 'Warning')
  $_ | Out-Host
}
#endregion
