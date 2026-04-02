$Object1 = Invoke-RestMethod -Uri 'https://updates.discord.com/distributions/app/manifests/latest?channel=ptb&platform=win&arch=arm64'

# Version
$this.CurrentState.Version = $Object1.full.host_version -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Object1.full.url 'DiscordPTBSetup.exe'
}

switch -Regex ($this.Check()) {
  'New|Updated' {
    $this.Print()
    $this.Write()
  }
  'Updated' {
    $this.Message()
    $this.Submit()
  }
}
