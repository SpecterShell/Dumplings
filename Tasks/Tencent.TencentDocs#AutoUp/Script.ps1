$Object1 = (Invoke-RestMethod -Uri 'https://docs.qq.com/api/packageupgrade/update_config?auto_update=true').result.auto_update.update_info | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($Object1.version)) {
  $this.Log('The API returned an invalid response', 'Warning')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

$Prefix = "https://desktop.docs.qq.com/update/release/$($this.CurrentState.Version)/"

# Installer (x86)
$Object2 = Invoke-RestMethod -Uri "${Prefix}latest-win32-ia32.yml" | ConvertFrom-Yaml
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $Object2.files[0].url
}

# Installer (x64)
$Object3 = Invoke-RestMethod -Uri "${Prefix}latest-win32-x64.yml" | ConvertFrom-Yaml
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $Object3.files[0].url
}

# Installer (arm64)
# $Object4 = Invoke-RestMethod -Uri "${Prefix}latest-win32-arm64.yml" | ConvertFrom-Yaml
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = $Prefix + $Object4.files[0].url
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesContent = $Object1.update_info.Split("`n`n")[0] | Split-LineEndings

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesContent[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesContent | Select-Object -Skip 2 | Format-Text
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

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockTencentDocs')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("TencentDocs-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["TencentDocs-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
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
