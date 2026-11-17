# x64
$Object1 = Invoke-RestMethod -Uri 'https://releases.diabrowser.com/windows/release/Dia.x64.appinstaller'
# arm64
$Object2 = Invoke-RestMethod -Uri 'https://releases.diabrowser.com/windows/release/Dia.arm64.appinstaller'

if ($Object1.AppInstaller.Version -ne $Object2.AppInstaller.Version) {
  $this.Log("Inconsistent versions: x64: $($Object1.AppInstaller.Version), arm64: $($Object2.AppInstaller.Version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.AppInstaller.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msix'
  InstallerUrl  = $Object1.AppInstaller.MainPackage.Uri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'msix'
  InstallerUrl  = $Object2.AppInstaller.MainPackage.Uri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # The Windows changelog embeds its entries as JSON in the Next.js __NEXT_DATA__ script
      $Object3 = Invoke-WebRequest -Uri 'https://www.diabrowser.com/changelog/windows' | ConvertFrom-Html
      $Object4 = $Object3.SelectSingleNode('//script[@id="__NEXT_DATA__"]').InnerHtml | ConvertFrom-Json
      $Object5 = $Object4.props.pageProps.releases[0]
      if (($Object5.platforms.windows.version.Split('.')[0..1] -join '.') -eq ($this.CurrentState.Version.Split('.')[0..1] -join '.')) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object5.date | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = @($Object5.platforms.windows.intro.text, $Object5.platforms.windows.items.ForEach({ "$($_.title)`n$($_.body.text)" })) | Join-String -Separator "`n`n" | Format-Text
        }
      } else {
        $this.Log("The changelog entry (v$($Object5.version)) does not match version $($this.CurrentState.Version)", 'Warning')
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
