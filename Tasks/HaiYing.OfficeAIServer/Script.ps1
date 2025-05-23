$Object1 = Invoke-RestMethod -Uri 'https://api.office-ai.cn/private_server/v1/update' -Method Post -Body (
  @{
    OfficeAIServer = $this.Status.Contains('New') ? '1.0.9' : $this.LastState.Version
  } | ConvertTo-Json -Compress
)

if ([string]::IsNullOrWhiteSpace($Object1.version)) {
  $this.Log($Object1.desc, 'Warning')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.bin_url.Replace('download.office-ai.cn', 'downloadcdn.office-ai.cn')
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
