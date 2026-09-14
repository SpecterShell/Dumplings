# The versionless alias on the download site redirects to the versioned installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://work.n.cn/pkg/win/Namiwork.exe'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
