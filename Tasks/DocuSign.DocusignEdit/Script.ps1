$Object1 = Invoke-RestMethod -Uri 'https://pub.springcm.com/published/201305/VersionInfo/docusign%20editv2%20windows'

# Version
$this.CurrentState.Version = $Object1.VersionInfo.VersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.VersionInfo.DownloadLocation | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
