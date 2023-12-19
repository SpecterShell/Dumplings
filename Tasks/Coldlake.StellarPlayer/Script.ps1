# Download
$Object1 = (Invoke-RestMethod -Uri 'https://api.stellarplayer.com/v1/cfg/getConfig?cfgKey=nZngW7WDWeVxm').data.cfgInfo.nZngW7WDWeVxm.cfgDetail | ConvertFrom-Json
$Version1 = [regex]::Match($Object1.filename, '(\d{14})').Groups[1].Value

# Upgrade
$Object2 = Invoke-RestMethod -Uri 'https://ab.coldlake1.com/v1/abt/matcher?arch=x64&atype=show&channel=official'
$Version2 = [regex]::Match($Object2.data, '(\d{14})').Groups[1].Value

if ((Compare-Version -ReferenceVersion $Version1 -DifferenceVersion $Version2) -gt 0) {
  # Version
  $this.CurrentState.Version = $Version2

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = "https://player-download.coldlake1.com/player/$($this.CurrentState.Version)/Stellar_$($this.CurrentState.Version)_official_stable_full_x64.exe"
  }
} else {
  # Version
  $this.CurrentState.Version = $Version1

  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.offical_http_address
  }
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $this.CurrentState.RealVersion = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Object3 = Invoke-WebRequest -Uri "https://player-update.coldlake1.com/version/gray/$($this.CurrentState.Version)_x64.ini" | Read-ResponseContent | ConvertFrom-Ini

    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object3.update.info | Format-Text
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
