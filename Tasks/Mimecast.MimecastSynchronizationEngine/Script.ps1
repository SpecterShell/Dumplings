$Link = $Global:DumplingsStorage.MimecastDownloadPage.SelectSingleNode('//tr[contains(./td[1], "Mimecast Synchronization Engine")]/td[2]//a')

# Version
$this.CurrentState.Version = [regex]::Match($Link.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x86'
  InstallerType       = 'zip'
  NestedInstallerType = 'nullsoft'
  InstallerUrl        = $Link.Attributes['href'].Value | ConvertTo-HtmlDecodedText
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      foreach ($Installer in $this.CurrentState.Installer) {
        $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
        $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
        $Installer['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.exe') }, 'First')[0].FullName.Replace('/', '\') })
        $ZipFile.Dispose()
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
