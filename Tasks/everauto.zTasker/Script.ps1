$Object1 = Invoke-RestMethod -Uri 'http://everauto.net:8080/up/ztv.ini' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.base.newver

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.base.url.Replace('_Update', '_Setup')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.base.time | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $ReleaseNotes = foreach ($KVP in $Object1.update.GetEnumerator()) {
        if (-not $KVP.Value.Contains('其它修复和改进') -and $KVP.Value -notmatch '^V(\d+(?:\.\d+)+) ') {
          $KVP.Value
        } else {
          break
        }
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes | Format-Text
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
