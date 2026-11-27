# Installer
# The download endpoint redirects to a version-specific CDN URL signed with a short-lived key, so the version-specific URL cannot be stored in a manifest.
$InstallerUri = 'https://api.nrd.nie.163.com/api/v1/release/dl/1?channel=gwqd'
$RedirectedUrl = Get-RedirectedUrl -Uri $InstallerUri

$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUri
}

# Version
$this.CurrentState.Version = [regex]::Match($RedirectedUrl, '(\d+(?:\.\d+){3})').Groups[1].Value

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
