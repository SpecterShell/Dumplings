$Object1 = (Invoke-RestMethod -Uri 'https://www.lebo.cn/downUrl.json').result.Where({ $_.type -eq 'pc' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Query             = @{}
  Architecture      = 'x86'
  InstallerUrl      = $Object1.url
  InstallerSwitches = @{}
  ProductCode       = 'PCCast'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.prompt | Get-Date -Format 'yyyy-MM-dd'
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
