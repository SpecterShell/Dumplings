$Object1 = (Invoke-GitHubApi -Uri "https://api.github.com/repos/freenginx/nginx/tags").Where({ $_.name.StartsWith("release-") }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.name -replace '^release-'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://freenginx.org/download/freenginx-$($this.CurrentState.Version).zip"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "freenginx-$($this.CurrentState.Version)/nginx.exe"
    }
  )
}

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
