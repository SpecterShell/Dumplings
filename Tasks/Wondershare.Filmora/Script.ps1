$Object1 = Invoke-RestMethod -Uri 'https://pc-api.300624.com/v2/product/check-upgrade?pid=846&client_sign={}&version=10.0.0.0&platform=win_x64'

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.wondershare.com/cbs_down/filmora_64bit_$($this.CurrentState.Version)_full846.exe"
  ProductCode  = "Wondershare Filmora $($this.CurrentState.Version.Split('.')[0])_is1"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.whats_new_content | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName = "Wondershare Filmora $($this.CurrentState.Version.Split('.')[0])(Build $($this.CurrentState.RealVersion))"
        ProductCode = "Wondershare Filmora $($this.CurrentState.Version.Split('.')[0])_is1"
      }
    )

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
