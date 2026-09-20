$Object1 = Invoke-RestMethod -Uri 'https://persistent.oaistatic.com/codex-app-prod/windows-store-update.json'

# Version
$this.CurrentState.Version = $Object1.buildVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://persistent.oaistatic.com/codex-app-prod/releases/$($this.CurrentState.Version)/ChatGPT-x64.msix"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://persistent.oaistatic.com/codex-app-prod/releases/$($this.CurrentState.Version)/ChatGPT-arm64.msix"
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
