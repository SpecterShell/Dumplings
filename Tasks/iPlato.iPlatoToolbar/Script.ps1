# The IT-managed install page publishes the full installer as
# iPlato_toolbar_<version>_admin.zip. The app's own update catalog
# (buddyapi.mygp.com/bwm/v1/installers) only serves MSP patches, so the
# page remains the authoritative source for full-installer releases.

$DownloadPage = 'https://www.iplato.com/support-centre/installing-the-iplato-toolbar-via-a-centrally-controlled-it-team/index.html'

$Page = Invoke-WebRequest -Uri $DownloadPage | ConvertFrom-Html

# Installer
$InstallerUrl = Join-Uri $DownloadPage $Page.SelectSingleNode('//a[contains(@href, "iPlato_toolbar_") and contains(@href, "_admin.zip")]').Attributes['href'].Value

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.Name.EndsWith('.msi') }, 'First')[0].FullName.Replace('/', '\') })
    $ZipFile.Dispose()

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
