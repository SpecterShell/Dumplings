$Object1 = Invoke-RestMethod -Uri 'https://www.pdf-xchange.com/build-history-feed/pdf-xchange-editor.xml'
$Object2 = $Object1[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object2.title, 'Build\s+([\d.]+)').Groups[1].Value

$MajorVersion = [version]$this.CurrentState.Version | Select-Object -ExpandProperty Major

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = "https://downloads.pdf-xchange.com/$($this.CurrentState.Version)/EditorV${MajorVersion}.x86.msi"
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://downloads.pdf-xchange.com/$($this.CurrentState.Version)/EditorV${MajorVersion}.x64.msi"
}
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = "https://downloads.pdf-xchange.com/$($this.CurrentState.Version)/EditorV${MajorVersion}.ARM64.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      # AppsAndFeaturesEntries + ProductCode
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          ProductCode   = $Installer['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
          UpgradeCode   = $InstallerFile | Read-UpgradeCodeFromMsi
          InstallerType = 'wix'
        }
      )
    }

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.pubDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $ReleaseNotes = $Object2.description.'#cdata-section' | ConvertFrom-Html | Get-TextContent | Format-Text
      if (-not [string]::IsNullOrWhiteSpace($ReleaseNotes)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
