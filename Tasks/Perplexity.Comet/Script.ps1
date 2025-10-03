# x64
$Object1 = Invoke-RestMethod -Uri 'https://www.perplexity.ai/rest/browser/update' -Body @{
  browser  = $this.Status.Contains('New') ? '137.1.7151.8097' : $this.LastState.Version
  channel  = 'stable'
  platform = 'win_x64'
  machine  = '0'
} -SkipHttpErrorCheck -StatusCodeVariable 'StatusCode' -MaximumRetryCount 0

if ($StatusCode -eq 404) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
} elseif ($StatusCode -ne 200) {
  $this.Log($Object1.status, 'Error')
  return
}

# # arm64
# $Object2 = Invoke-RestMethod -Uri 'https://www.perplexity.ai/rest/browser/update' -Body @{
#   browser  = $this.Status.Contains('New') ? '137.1.7151.8097' : $this.LastState.Version
#   channel  = 'stable'
#   platform = 'win_arm64'
#   machine  = '0'
# } -SkipHttpErrorCheck -StatusCodeVariable 'StatusCode' -MaximumRetryCount 0

# if ($StatusCode -eq 404) {
#   $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
#   return
# } elseif ($StatusCode -ne 200) {
#   $this.Log($Object1.status, 'Error')
#   return
# }

# if ($Object1.body.browser_version -ne $Object2.body.browser_version) {
#   $this.Log("Inconsistent versions: x64: $($Object1.body.browser_version), arm64: $($Object2.body.browser_version)", 'Error')
#   return
# }

# Version
$this.CurrentState.Version = $Object1.body.browser_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.body.url
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = $Object2.body.url
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
