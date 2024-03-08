$UpstreamOwner = $Global:DumplingsPreference['UpstreamOwner'] ?? $this.Config['UpstreamOwner']
$UpstreamRepo = $Global:DumplingsPreference['UpstreamRepo'] ?? $this.Config['UpstreamRepo']
$UpstreamBranch = $Global:DumplingsPreference['UpstreamBranch'] ?? $this.Config['UpstreamBranch']
$OriginOwner = $Global:DumplingsPreference['OriginOwner'] ?? $this.Config['OriginOwner']
$OriginRepo = $Global:DumplingsPreference['OriginRepo'] ?? $this.Config['OriginRepo']
$OriginBranch = $Global:DumplingsPreference['OriginBranch'] ?? $this.Config['OriginBranch']

$Query = @"
{
  repository(owner: "${OriginOwner}", name: "${OriginRepo}") {
    refs(
      refPrefix: "refs/heads/"
      last: 100
      orderBy: { field: TAG_COMMIT_DATE, direction: ASC }
    ) {
      nodes {
        name
        associatedPullRequests(last: 1, orderBy: { field: CREATED_AT, direction: DESC }) {
          nodes {
            number
            state
            isDraft
            url
            timelineItems(
              last: 1
              itemTypes: [HEAD_REF_DELETED_EVENT, HEAD_REF_RESTORED_EVENT]
            ) {
              nodes {
                __typename
              }
            }
          }
        }
      }
    }
  }
}
"@
$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/graphql' -Method Post -Body @{ query = $Query }
$Branches = $Object1.data.repository.refs.nodes.Where({ $_.associatedPullRequests.nodes.Count -gt 0 -and $_.associatedPullRequests.nodes[0].state -eq 'MERGED' })

$this.Log("$($Branches.Count) branch(es) in ${OriginOwner}/${OriginRepo} have been merged. Deleting...")

$Count = 0
foreach ($Branch in $Branches) {
  try {
    $this.Log("Deleting $($Branch.name)")
    Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/refs/heads/$($Branch.name)" -Method Delete | Out-Null
    $Count++
  } catch {
    $this.Log("Failed to delete branch $($Branch.name)", 'Error')
    $_ | Out-Host
  }
}

$this.Log("$($Branches.Count) branch(es) to delete, ${Count} deleted, $($Branches.Count - $Count) not deleted")

$this.Log("Updating ${OriginOwner}/${OriginRepo}/${OriginBranch} to ${UpstreamOwner}/${UpstreamRepo}/${UpstreamBranch}")

$UpstreamSha = $Global:DumplingsStorage['UpstreamSha'] ??= (Invoke-GitHubApi -Uri "https://api.github.com/repos/${UpstreamOwner}/${UpstreamRepo}/git/ref/heads/${UpstreamBranch}").object.sha

Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/refs/heads/${OriginBranch}" -Method Patch -Body @{
  sha = $UpstreamSha
} | Out-Null

$this.Log("${OriginOwner}/${OriginRepo}/${OriginBranch} has been fast-forwarded to ${UpstreamOwner}/${UpstreamRepo}/${UpstreamBranch}")
