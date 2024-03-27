# Version
$this.CurrentState.Version = [regex]::Match(
  (Invoke-WebRequest -Uri 'https://www.blender.org/download/').Content,
  'blender-([\w\.]+)-windows'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = "https://download.blender.org/release/Blender$($this.CurrentState.Version.Split('.')[0..1] -join '.')/blender-$($this.CurrentState.Version)-windows-x64.msi"
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = "https://www.blender.org/download/releases/$($this.CurrentState.Version.Split('.')[0..1] -join '-')/"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    $Installer['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $Installer['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
        UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
      }
    )

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
