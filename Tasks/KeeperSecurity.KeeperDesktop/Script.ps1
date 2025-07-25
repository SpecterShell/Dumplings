$Object1 = Invoke-RestMethod -Uri 'https://download.keepersecurity.com/desktop_electron/packages/KeeperPasswordManager.appinstaller'

# Version
$this.CurrentState.Version = $Object1.AppInstaller.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msix'
  InstallerUrl  = $Object1.AppInstaller.MainBundle.Uri
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture  = 'x86'
#   InstallerType = 'wix'
#   InstallerUrl  = Join-Uri $Object1.AppInstaller.MainBundle.Uri '../Win32/KeeperSetup32.msi'
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://docs.keeper.io/en/release-notes/desktop/web-vault-+-desktop-app'
      }

      $Object2 = Invoke-WebRequest -Uri "https://docs.keeper.io/en/release-notes/desktop/web-vault-+-desktop-app/vault-release-$($this.CurrentState.Version -replace '(\.0+)+$')" | ConvertFrom-Html

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('//main/header/p').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # Remove psuedo bullet points
      $Object2.SelectNodes('//main/div[1]//li/div[contains(./div/@style, "•")]').ForEach({ $_.Remove() })
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode('//main/div[1]') | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://docs.keeper.io/en/release-notes/desktop/web-vault-+-desktop-app/vault-release-$($this.CurrentState.Version.Split('.')[0..2] -join '.')"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
