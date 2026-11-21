$Object1 = Invoke-RestMethod -Uri 'https://api.pixcakeai.com/v1/app/update_config' -Body @{
  app_type  = '12'
  is_manual = '1'
  version   = $this.Status.Contains('New') ? '9.2.0-23' : $this.LastState.Version
}

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.data.package_download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.UpdatedAt.ToUniversalTime()

      $Object2 = $Object1.data.release_note | ConvertFrom-Json

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += @{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.updateContent | Format-Text
      }
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
