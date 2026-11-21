$Object1 = Invoke-RestMethod -Uri 'http://update.everedit.net/checkver.php' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Version.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.everedit.net/latest.php?cpu=x86'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.everedit.net/latest.php?cpu=x64'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-WebRequest -Uri 'https://www.everedit.net/changelog' -Headers @{ Cookie = 'lang=en' }).Content | Get-EmbeddedJson -StartsFrom 'let rows = ' | ConvertFrom-Json

      $ReleaseNotesNode = $Object2.Where({ $_.title.StartsWith("EverEdit $($this.CurrentState.Version)") }, 'First')
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesNode[0].createAt | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode[0].content | Convert-MarkdownToHtml | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = (Invoke-WebRequest -Uri 'https://www.everedit.net/changelog' -Headers @{ Cookie = 'lang=zh_cn' }).Content | Get-EmbeddedJson -StartsFrom 'let rows = ' | ConvertFrom-Json

      $ReleaseNotesCNNode = $Object3.Where({ $_.title.StartsWith("EverEdit $($this.CurrentState.Version)") }, 'First')
      if ($ReleaseNotesCNNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $ReleaseNotesCNNode[0].createAt | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNode[0].content | Convert-MarkdownToHtml | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
