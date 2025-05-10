$Object1 = Invoke-RestMethod -Uri 'https://plangrid-windows-installer.s3.amazonaws.com/production/UpdateManifest2.json' | Get-EmbeddedJson | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.releases_x64_win10[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.releases_x64_win10[0].downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releases_x64_win10[0].releaseDate | ConvertFrom-UnixTimeSeconds

      # # ReleaseNotes (en-US)
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'en-US'
      #   Key    = 'ReleaseNotes'
      #   Value  = $Object1.releases_x64_win10[0].notes | Format-Text
      # }
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
