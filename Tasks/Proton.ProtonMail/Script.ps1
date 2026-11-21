$Object1 = (Invoke-WebRequest -Uri 'https://proton.me/download/mail/windows/version.json' | Read-ResponseContent | ConvertFrom-Json -AsHashtable).Releases.Where({ $_.CategoryName -eq 'Stable' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://proton.me/download/mail/windows/$($this.CurrentState.Version)/ProtonMail-desktop.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.ReleaseNotes | ForEach-Object -Process {
          $TypeName = switch ($_.Type) {
            'Improvement' { 'Improvements' }
            'Fix' { 'Bug Fixes' }
            'Feature' { 'New Features' }
            Default { $_ }
          }
          "${TypeName}`n$($_.Notes | ConvertTo-UnorderedList)"
        } | Join-String -Separator "`n" | Format-Text
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
