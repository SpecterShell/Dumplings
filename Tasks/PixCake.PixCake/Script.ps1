$Object1 = Invoke-RestMethod -Uri 'https://pixweb-api.pixcakeai.com/v1/web/software/list'
$Release = $Object1.data.Where({ $_.package.app_type -eq 16 -and $_.package.available }) | Sort-Object -Property { [datetime]$_.published_at } -Bottom 1

# Version
$this.CurrentState.Version = $Release.package.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Release.package.full_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Release.published_at.ToUniversalTime()
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
