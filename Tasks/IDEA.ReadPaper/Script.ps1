$Object1 = Invoke-RestMethod -Uri 'https://readpaper.com/api/microService-app-aiKnowledge/aiKnowledge/client/v1/getDownloadUrls' -Method Post -ContentType 'application/json' -Body '{}'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.urls.windowsClient
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

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
