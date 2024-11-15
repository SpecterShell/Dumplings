$Object1 = Invoke-WebRequest -Uri 'https://download.teamviewer.com/download/update/TVVersion15.txt'

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://download.teamviewer.com/download/version_$($this.CurrentState.Version.Split('.')[0])x/TeamViewer_Setup_$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://download.teamviewer.com/download/version_$($this.CurrentState.Version.Split('.')[0])x/TeamViewer_Setup_x64_$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x86'
  InstallerType       = 'zip'
  NestedInstallerType = 'wix'
  InstallerUrl        = "https://download.teamviewer.com/download/version_$($this.CurrentState.Version.Split('.')[0])x/update/Update_msi_$($this.CurrentState.Version).zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'wix'
  InstallerUrl        = "https://download.teamviewer.com/download/version_$($this.CurrentState.Version.Split('.')[0])x/update/Update_msi_$($this.CurrentState.Version)_x64.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-WebRequest -Uri "https://whatsnew.teamviewer.com/en/whatsnew/teamviewer-client/$($this.CurrentState.Version.Replace('.', '-'))/full.json").Content | ConvertFrom-Json -AsHashtable

      # ReleaseNotes (en-US)
      $ReleaseNotes = [System.Text.StringBuilder]::new()
      if ($Object2.changelog.Contains('features')) {
        $ReleaseNotes = $ReleaseNotes.AppendLine('New Features')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object2.changelog.features.html | ConvertFrom-Html | Get-TextContent))
      }
      if ($Object2.changelog.Contains('improvements')) {
        $ReleaseNotes = $ReleaseNotes.AppendLine('Improvements')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object2.changelog.improvements.html | ConvertFrom-Html | Get-TextContent))
      }
      if ($Object2.changelog.Contains('bugfixes')) {
        $ReleaseNotes = $ReleaseNotes.AppendLine('Bugfixes')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object2.changelog.bugfixes.html | ConvertFrom-Html | Get-TextContent))
      }
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes.ToString() | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = (Invoke-WebRequest -Uri "https://whatsnew.teamviewer.com/de/whatsnew/teamviewer-client/$($this.CurrentState.Version.Replace('.', '-'))/full.json").Content | ConvertFrom-Json -AsHashtable

      # ReleaseNotes (de-DE)
      $ReleaseNotes = [System.Text.StringBuilder]::new()
      if ($Object3.changelog.Contains('features')) {
        $ReleaseNotes = $ReleaseNotes.AppendLine('Neue Funktionen')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object3.changelog.features.html | ConvertFrom-Html | Get-TextContent))
      }
      if ($Object3.changelog.Contains('improvements')) {
        $ReleaseNotes = $ReleaseNotes.AppendLine('Verbesserungen')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object3.changelog.improvements.html | ConvertFrom-Html | Get-TextContent))
      }
      if ($Object3.changelog.Contains('bugfixes')) {
        $ReleaseNotes = $ReleaseNotes.AppendLine('Fehlerkorrekturen')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object3.changelog.bugfixes.html | ConvertFrom-Html | Get-TextContent))
      }
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'de-DE'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes.ToString() | Format-Text
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
