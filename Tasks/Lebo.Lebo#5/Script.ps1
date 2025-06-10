$Object1 = (Invoke-WebRequest -Uri 'http://hotupgrade.hpplay.cn:8999/Author/UpdateApp' -Body @{
    appid       = '10619'
    model       = 'Windows'
    api_version = $this.Status.Contains('New') ? '50566' : $this.LastState.VersionCode
    mac         = '00:00:00:00:00:00'
  }).Content | ConvertFrom-Json -AsHashtable

if ($Object1.data.Count -eq 0) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.cversion

# VersionCode
$this.CurrentState.VersionCode = $Object1.data.aversion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Query             = @{}
  Architecture      = 'x86'
  InstallerUrl      = $Object1.data.aurl
  InstallerSwitches = @{}
  ProductCode       = 'PCCast'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.updatetime | ConvertFrom-UnixTimeMilliseconds

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.upNotes | Format-Text
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
