$Object1 = Invoke-RestMethod -Uri 'https://api.binaryfortress.com/UpdateCheck/' -Method Post -Headers @{'BFAPI-TargetProductID' = '128' } -Body (
  @{
    cpu = 64
  } | ConvertTo-Json -Compress
)

# Version
$this.CurrentState.Version = $Object1.update.version | ConvertFrom-Base64 -Encoding 'utf-16'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri ($Object1.update.urlDownloadInstaller | ConvertFrom-Base64 -Encoding 'utf-16')
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
