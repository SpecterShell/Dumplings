$Prefix = 'https://www.uziregister.nl/uzi-pas/activeer-en-installeer-uw-uzi-pas/overzicht-safesign-software'
$Object1 = Invoke-WebRequest -Uri $Prefix

$Link = Join-Uri $Prefix $Object1.Links.Where({ try { $_.outerHTML.Contains('Windows 64-bit') } catch {} }, 'First')[0].href
$Object2 = Invoke-WebRequest -Uri $Link -Method Head
if ($Object2.Headers.'Content-Type' -match 'text/html') {
  $Object2 = Invoke-WebRequest -Uri ($Prefix = $Link)
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.outerHTML.Contains('Windows 64-bit') } catch {} }, 'First')[0].href
  }
} else {
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Link
  }
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = @(
        [ordered]@{
          RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.msi') }, 'First')[0].FullName.Replace('/', '\')
        }
      )
      $ZipFile.Dispose()
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
