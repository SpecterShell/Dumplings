$Object1 = Invoke-RestMethod -Uri 'https://updates.fournova.com/tower3-win/stable/releases/latest.json'

# Version
$this.CurrentState.Version = "$($Object1.version).$($Object1.build_number)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType          = 'exe'
  InstallerUrl           = $Object1.url
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version
    }
  )
}
$this.CurrentState.Installer += $InstallerWiX = [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $Object1.msi_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = ($Object1.release_notes -join "`n" | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerWiXFile = Get-TempFile -Uri $InstallerWiX.InstallerUrl
    $InstallerWiX['InstallerSha256'] = (Get-FileHash -Path $InstallerWiXFile -Algorithm SHA256).Hash
    $InstallerWiX['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = 'Tower Deployment Tool'
        DisplayVersion = $InstallerWiXFile | Read-ProductVersionFromMsi
        ProductCode    = $InstallerWiX['ProductCode'] = $InstallerWiXFile | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerWiXFile | Read-UpgradeCodeFromMsi
      }
    )

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
