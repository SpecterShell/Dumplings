$Object1 = (Invoke-WebRequest -Uri 'https://is.snssdk.com/service/settings/v3/' -Body @{
    device_platform = 'windows'
    os_version      = '10.0.22000'
    aid             = '3704'
    iid             = '0'
    version_code    = $this.LastState.Contains('VersionCode') ? $this.LastState.VersionCode : '197888'
    rom_version     = '0'
  }).Content | ConvertFrom-Json -AsHashtable

if (-not $Object1.data.settings.Contains('update_reminder')) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# VersionCode
$this.CurrentState.VersionCode = $VersionCode = $Object1.data.settings.update_reminder.lastest_stable_version

# Version
$this.CurrentState.Version = @(
  [math]::Floor($VersionCode / 256 / 256).ToString()
  [math]::Floor($VersionCode / 256 % 256).ToString()
  [math]::Floor($VersionCode % 256).ToString()
  $Object1.data.settings.update_reminder.lastest_stable_builder_number.ToString()
) -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.settings.update_reminder.lastest_stable_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.settings.update_reminder.lastest_stable_update_content | Format-Text
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
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsJianyingPro')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("JianyingProSubmitting-$($this.CurrentState.Version)")) {
      $Global:DumplingsStorage["JianyingProSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
    }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()

    if ($ToSubmit) {
      $this.Submit()
    } else {
      $this.Log('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
