$Prefix = 'https://updates.desktop.evernote.com/win/public/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'en-US'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = Invoke-RestMethod -Uri "https://release-notes.evernote.com/desktop/$($this.CurrentState.Version)/desktop/en.txt" | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = Invoke-RestMethod -Uri "https://release-notes.evernote.com/desktop/$($this.CurrentState.Version)/desktop/zh-cn.txt" | Format-Text
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
