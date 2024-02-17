$Object1 = Invoke-RestMethod -Uri 'https://ideservice.alipay.com/ide/api/pluginVersion.json?platform=win&clientType=assistant' -Headers @{ Referer = 'https://openhome.alipay.com' }

# Version
$this.CurrentState.Version = $Object1.baseResponse.data.versionName

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.baseResponse.data.downloadUrl
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
