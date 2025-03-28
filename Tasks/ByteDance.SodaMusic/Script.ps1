$Object1 = (Invoke-WebRequest -Uri 'https://conf.qishui.com/service/settings/v3/?aid=386088').Content | ConvertFrom-Json -AsHashtable

if (-not $Object1.data.settings.Contains('update_info')) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$this.CurrentState.Version = $Object1.data.settings.update_info.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x86'
  InstallerUrl    = $Object1.data.settings.update_info.win32.ia32.url
  InstallerSha256 = $Object1.data.settings.update_info.win32.ia32.sha256
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerUrl    = $Object1.data.settings.update_info.win32.x64.url
  InstallerSha256 = $Object1.data.settings.update_info.win32.x64.sha256
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.settings.update_info.layoutInfo.updateDialogContent | Format-Text
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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockSodaMusic')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("SodaMusic-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["SodaMusic-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
