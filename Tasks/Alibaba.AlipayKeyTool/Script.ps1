$Object1 = Invoke-RestMethod -Uri 'https://ideservice.alipay.com/ide/api/pluginVersion.json?platform=win&clientType=assistant' -Headers @{ Referer = 'https://openhome.alipay.com' }

# Version
$this.CurrentState.Version = $Object1.baseResponse.data.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.baseResponse.data.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
