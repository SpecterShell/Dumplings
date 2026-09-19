$Prefix = 'https://minireel.weppp.cyou:54267/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}api/releases?platform=windows"
$Release = @($Object1.items) | Sort-Object -Property { [version]$_.version } -Descending | Select-Object -First 1

# Version
$this.CurrentState.Version = $Release.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Release.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Release.publishedAt | Get-Date -AsUTC

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Release.summary
      }

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = Join-Uri $Prefix "release/$($Release.id)"
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
