# x64 EXE
$Object1 = Invoke-RestMethod -Uri 'https://slack.com/api/desktop.latestRelease?arch=x64&variant=exe'
# x64 MSI
$Object2 = Invoke-RestMethod -Uri 'https://slack.com/api/desktop.latestRelease?arch=x64&variant=msi'
# x64 MSIX
$Object3 = Invoke-RestMethod -Uri 'https://slack.com/api/desktop.latestRelease?arch=x64&variant=msix'
# arm64 MSIX
$Object4 = Invoke-RestMethod -Uri 'https://slack.com/api/desktop.latestRelease?arch=arm64&variant=msix'

if ($Object1.version -ne $Object2.version) {
  $this.Log("x64 EXE version: $($Object1.version)")
  $this.Log("x64 WiX version: $($Object2.version)")
  $this.Log("x64 MSIX version: $($Object3.version)")
  $this.Log("arm64 MSIX version: $($Object4.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = $Object1.download_url
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Object2.download_url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msix'
  InstallerUrl  = $Object3.version -eq $Object1.version ? $Object3.download_url : "https://downloads.slack-edge.com/desktop-releases/windows/x64/$($this.CurrentState.Version)/Slack.msix"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'msix'
  InstallerUrl  = $Object4.version -eq $Object1.version ? $Object4.download_url : "https://downloads.slack-edge.com/desktop-releases/windows/arm64/$($this.CurrentState.Version)/Slack.msix"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # ProductCode
    $Installer['ProductCode'] = "$($InstallerFile | Read-ProductCodeFromMsi).msq"

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://slack.com/release-notes/windows'
      }

      $Object4 = (Invoke-RestMethod -Uri 'https://slack.com/release-notes/windows/rss').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object4) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object4[0].pubDate | Get-Date -AsUTC

        $ReleaseNotesObject = $Object4[0].encoded.'#cdata-section' | ConvertFrom-Html
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not ($Node.Name -eq 'h3' -and $Node.InnerText.Contains('Downloads')); $Node = $Node.NextSibling) { $Node }
        if ($ReleaseNotesNodes) {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object4[0].link
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
