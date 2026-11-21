$Object1 = Invoke-RestMethod -Uri 'https://static-openapi.stepfun.com/stepcode/latest.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $Object1.packages.'windows-x64'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'arm64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $Object1.packages.'windows-arm64'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.generatedAt | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
