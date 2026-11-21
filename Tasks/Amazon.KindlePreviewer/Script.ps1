$Object1 = Invoke-RestMethod -Uri 'https://kindlepreviewer.s3.amazonaws.com/Update.xml'

# Version
$this.CurrentState.Version = $Object1.xml.content.update.windows.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.xml.content.update.windows.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.xml.content.update.windows.notes.Where({ $_.locale -eq 'en' }, 'First')[0].'#text' | Format-Text
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.xml.content.update.windows.notes.Where({ $_.locale -eq 'zh' }, 'First')[0].'#text' | Format-Text
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
