$Object1 = Invoke-RestMethod -Uri 'https://modelscope.cn/api/v1/aigc/flowbench/deps'

# Version
$this.CurrentState.Version = $Object1.Data.Preview.LatestVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Data.Preview.Versions.($this.CurrentState.Version).Win
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
