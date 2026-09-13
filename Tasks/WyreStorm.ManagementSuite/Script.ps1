$Object1 = Invoke-WebRequest -Uri 'https://www.wyrestorm.com/management-suite/' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//a[.//img/@src="https://www.wyrestorm.com/wp-content/uploads/2021/07/Download-Image.png"]').Attributes['href'].Value | ConvertTo-HtmlDecodedText
}

$Object2 = Get-WebResponseHeader -Uri $this.CurrentState.Installer[0].InstallerUrl

# Version
$this.CurrentState.Version = [regex]::Match(
  [System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse($Object2.Headers.'Content-Disposition'[0]).FileName,
  '(\d+(?:\.\d+)+)'
).Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.exe') }, 'First')[0].FullName.Replace('/', '\') })
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
