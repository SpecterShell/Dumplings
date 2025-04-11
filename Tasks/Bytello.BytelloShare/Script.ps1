# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = 'https://ssp.bytello.com/download?agent=d'
}

# Version
$this.CurrentState.Version = [regex]::Match((Get-RedirectedUrl -Uri $this.CurrentState.Installer[0].InstallerUrl), '(\d+(?:\.\d+){3})').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  InstallerType        = 'zip'
  NestedInstallerType  = 'wix'
  InstallerUrl         = 'https://ssp.bytello.com/download?agent=g'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "BytelloShare_Win_$($this.CurrentState.Version).msi"
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
