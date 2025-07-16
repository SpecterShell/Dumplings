$Object1 = Invoke-WebRequest -Uri 'https://goteleport.com/download/' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//script[@id="__NEXT_DATA__"]').InnerHtml | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object2.props.pageProps.initialDownloads[0].versions[0].version

# Installer
$Asset = $Object2.props.pageProps.initialDownloads[0].versions[0].assets.Where({ $_.os -eq 'windows' -and $_.arch -eq 'amd64' -and $_.description -eq 'Teleport Connect' }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerUrl    = $Asset.publicUrl | ConvertTo-UnescapedUri
  InstallerSha256 = $Asset.sha256.Trim().ToUpper()
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
