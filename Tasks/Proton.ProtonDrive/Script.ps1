$Object1 = (Invoke-RestMethod -Uri 'https://proton.me/download/drive/windows/version.json').Releases.Where({ $_.CategoryName -eq 'Stable' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.File.Url | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = (
    $Object1.ReleaseNotes | ForEach-Object -Process {
      $TypeName = switch ($_.Type) {
        'Improvement' { 'Improvements' }
        'Fix' { 'Bug Fixes' }
        'Feature' { 'New Features' }
        Default { $_ }
      }
      "${TypeName}`n$($_.Notes | ConvertTo-UnorderedList)"
    }
  ) -join "`n" | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
