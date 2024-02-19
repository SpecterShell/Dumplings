$Object1 = Invoke-RestMethod -Uri 'https://readpaper.com/api/microService-app-aiKnowledge/aiKnowledge/client/v1/getDownloadUrls' -Method Post -ContentType 'application/json' -Body '{}'

$Prefix = [uri]::new([uri]$Object1.data.urls.windowsClient, '.').OriginalString

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

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
