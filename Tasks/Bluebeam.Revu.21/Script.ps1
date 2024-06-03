$Object1 = Invoke-RestMethod -Uri 'https://updatesservice-p-xx-ue1.bluebeam.com/api/ProductUpdates' -Method Post -Body (
  @{
    Version = $this.LastState.Contains('Version') ? $this.LastState.Version : '21.1.0'
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
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $NestedInstallerFileRoot = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${NestedInstallerFileRoot}" $InstallerFile 'Bluebeam Revu x64 21.msi' | Out-Host
    $NestedInstallerFile = Join-Path $NestedInstallerFileRoot 'Bluebeam Revu x64 21.msi'

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName = 'Bluebeam Revu x64 21'
        ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $NestedInstallerFile | Read-ProductCodeFromMsi
        UpgradeCode = $NestedInstallerFile | Read-UpgradeCodeFromMsi
      }
    )

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
    $this.Submit()

    try {
      # Also submit manifests for sub module
      $this.Log("Handling $($this.Config.WinGetIdentifierModule)...", 'Info')
      $this.Config.WinGetIdentifier = $this.Config.WinGetIdentifierModule
      $this.CurrentState.Locale = @()
      $this.Config.IgnorePRCheck = $true

      7z.exe e -aoa -ba -bd -y -o"${NestedInstallerFileRoot}" $InstallerFile 'BluebeamOCR x64 21.msi' | Out-Host
      $NestedInstallerFile2 = Join-Path $NestedInstallerFileRoot 'BluebeamOCR x64 21.msi'

      # Version
      $this.CurrentState.Version = $NestedInstallerFile2 | Read-ProductVersionFromMsi

      # AppsAndFeaturesEntries
      $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $NestedInstallerFile2 | Read-ProductCodeFromMsi
          UpgradeCode = $NestedInstallerFile2 | Read-UpgradeCodeFromMsi
        }
      )

      $this.Submit()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }
  }
}
