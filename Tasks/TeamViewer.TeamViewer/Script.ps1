$Object1 = Invoke-WebRequest -Uri 'https://download.teamviewer.com/download/update/TVVersion15.txt'
# $Object1 = Invoke-WebRequest -Uri 'https://download.teamviewer.com/download/update/TVMSIVersion15.txt'

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
      $Object2 = curl -fsSLA $DumplingsInternetExplorerUserAgent "https://whatsnew.teamviewer.com/en/whatsnew/teamviewer-client/$($this.CurrentState.Version.Replace('.', '-'))/full.json" | Join-String -Separator "`n" | ConvertFrom-Json

      # ReleaseNotes (en-US)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = @"
New Features
$($Object2.changelog.features.html | ConvertFrom-Html | Get-TextContent)

Improvements
$($Object2.changelog.improvements.html | ConvertFrom-Html | Get-TextContent)

Bugfixes
$($Object2.changelog.bugfixes.html | ConvertFrom-Html | Get-TextContent)
"@ | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = curl -fsSLA $DumplingsInternetExplorerUserAgent "https://whatsnew.teamviewer.com/de/whatsnew/teamviewer-client/$($this.CurrentState.Version.Replace('.', '-'))/full.json" | Join-String -Separator "`n" | ConvertFrom-Json

      # ReleaseNotes (de-DE)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'de-DE'
        Key    = 'ReleaseNotes'
        Value  = @"
New Features
$($Object3.changelog.features.html | ConvertFrom-Html | Get-TextContent)

Improvements
$($Object3.changelog.improvements.html | ConvertFrom-Html | Get-TextContent)

Bugfixes
$($Object3.changelog.bugfixes.html | ConvertFrom-Html | Get-TextContent)
"@ | Format-Text
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
