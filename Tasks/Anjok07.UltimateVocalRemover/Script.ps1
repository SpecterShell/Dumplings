$RepoOwner = 'Anjok07'
$RepoName = 'ultimatevocalremovergui'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Installer
$Asset = $Object1.assets | Where-Object -Property 'name' -Match -Value 'UVR_v([\d\.]+)_setup\.exe' | Sort-Object -Property { $_.name -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Asset.browser_download_url | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($Asset.name, 'v([\d\.]+)').Groups[1].Value

# ReleaseTime
$this.CurrentState.ReleaseTime = $Asset.updated_at.ToUniversalTime()

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.html_url
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
