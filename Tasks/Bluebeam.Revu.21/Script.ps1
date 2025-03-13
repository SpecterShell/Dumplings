$Object1 = Invoke-RestMethod -Uri 'https://updatesservice-p-xx-ue1.bluebeam.com/api/ProductUpdates' -Method Post -Body (
  @{
    Version = $this.Status.Contains('New') ? $this.LastState.Version : '21.1.0'
    Is32Bit = $false
  } | ConvertTo-Json -Compress
) -ContentType 'application/json; charset=utf-8'

# Version
$this.CurrentState.Version = $Object1.update.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://downloads.bluebeam.com/software/downloads/$($this.CurrentState.Version)/MSIBluebeamRevu$($this.CurrentState.Version)x64.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.update.releaseNote | ConvertFrom-Html | Get-TextContent | Format-Text
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
    # Avoid downloading the installer twice when handling sub module
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    $this.Submit()

    try {
      # Also submit manifests for sub module
      $this.Log("Handling $($this.Config.WinGetIdentifierModule)...", 'Info')
      $this.Config.WinGetIdentifier = $this.Config.WinGetIdentifierModule
      $this.CurrentState.Locale = @()
      $this.Config.IgnorePRCheck = $true

      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'BluebeamOCR x64 21.msi' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'BluebeamOCR x64 21.msi'
      # Version
      $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromMsi
      # AppsAndFeaturesEntries
      $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
          UpgradeCode = $InstallerFile2 | Read-UpgradeCodeFromMsi
        }
      )

      $this.Submit()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }
  }
}
