$Object1 = Invoke-RestMethod -Uri 'http://update.everedit.net/checkver.php' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Version.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'http://www.everedit.net/latest.php?cpu=x86'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'http://www.everedit.net/latest.php?cpu=x64'
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = (Invoke-WebRequest -Uri 'https://www.everedit.net/changelog' -Headers @{ Cookie = 'lang=en' }).Content | Get-EmbeddedJson -StartsFrom 'let rows = ' | ConvertFrom-Json

      $ReleaseNotesNode = $Object2.Where({ $_.title.StartsWith("EverEdit $($this.CurrentState.Version)") })
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesNode[0].createAt | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNode[0].content | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    try {
      $Object3 = (Invoke-WebRequest -Uri 'https://www.everedit.net/changelog' -Headers @{ Cookie = 'lang=zh_cn' }).Content | Get-EmbeddedJson -StartsFrom 'let rows = ' | ConvertFrom-Json

      $ReleaseNotesCNNode = $Object3.Where({ $_.title.StartsWith("EverEdit $($this.CurrentState.Version)") })
      if ($ReleaseNotesCNNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $ReleaseNotesCNNode[0].createAt | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesCNNode[0].content | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
