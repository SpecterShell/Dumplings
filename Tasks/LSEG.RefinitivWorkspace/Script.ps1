$Object1 = Invoke-RestMethod 'https://workspace.refinitiv.com/Apps/ProductDownloadPage/GetPublicLatestPackageUrl' -Method Post -Body 'EIKONLIGHTWINDOWS64'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Trim()
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

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
