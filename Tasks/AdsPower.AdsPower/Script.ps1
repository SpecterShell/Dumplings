# x86
$Object1 = Invoke-RestMethod -Uri 'https://api.adspower.net/client/sys-client-version/get-latest-version?system=com_win32'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://api.adspower.net/client/sys-client-version/get-latest-version?system=com_win64'

if ($Object1.data.version -ne $Object2.data.version) {
  $this.Log("Inconsistent versions: x86: $($Object1.data.version), x64: $($Object2.data.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object2.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.data.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.release.'en-US' | Format-Text
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.release.'zh-CN' | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Prefix = $Object1.data.latest

      $Object3 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

      if ($Object3.version -eq $this.CurrentState.Version) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object3.releaseDate | Get-Date -AsUTC
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
