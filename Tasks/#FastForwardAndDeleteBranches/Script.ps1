$UpstreamOwner = $Global:DumplingsPreference['UpstreamOwner'] ?? $this.Config['UpstreamOwner']
$UpstreamRepo = $Global:DumplingsPreference['UpstreamRepo'] ?? $this.Config['UpstreamRepo']
$UpstreamBranch = $Global:DumplingsPreference['UpstreamBranch'] ?? $this.Config['UpstreamBranch']
$OriginOwner = $Global:DumplingsPreference['OriginOwner'] ?? $this.Config['OriginOwner']
$OriginRepo = $Global:DumplingsPreference['OriginRepo'] ?? $this.Config['OriginRepo']
$OriginBranch = $Global:DumplingsPreference['OriginBranch'] ?? $this.Config['OriginBranch']

#region Delete merged branches
$Branches = @()
$Cursor = $null
do {
  $Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/graphql' -Method Post -Body @{
    query = @"
{
  repository(owner: "${OriginOwner}", name: "${OriginRepo}") {
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
} while ($Object1.data.repository.refs.pageInfo.hasNextPage)

$this.Log("$($Branches.Count) branch(es) in the repo ${OriginOwner}/${OriginRepo} have been merged. Deleting...")
foreach ($Branch in $Branches) {
  try {
    $this.Log("Deleting the branch $($Branch.name). Merged in:")
    foreach ($PullRequest in $Branch.associatedPullRequests.nodes) {
      $this.Log("  [$($PullRequest.state)] #$($PullRequest.number) - $($PullRequest.title) - $($PullRequest.url)")
    }
    $null = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/refs/heads/$($Branch.name)" -Method Delete
  } catch {
    $this.Log("Failed to delete the branch $($Branch.name): ${_}", 'Warning')
    $_ | Out-Host
  }
}
#endregion

#region Fast-forward
$this.Log("Updating the branch ${OriginOwner}/${OriginRepo}/${OriginBranch} to ${UpstreamOwner}/${UpstreamRepo}/${UpstreamBranch}")

try {
  $null = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/refs/heads/${OriginBranch}" -Method Patch -Body @{
    sha = $Global:DumplingsStorage['UpstreamSha'] ??= (Invoke-GitHubApi -Uri "https://api.github.com/repos/${UpstreamOwner}/${UpstreamRepo}/git/ref/heads/${UpstreamBranch}").object.sha
  }
} catch {
  $this.Log("Failed to update the branch: ${_}", 'Warning')
  $_ | Out-Host
}
#endregion
