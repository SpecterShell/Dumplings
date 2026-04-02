$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/aws/aws-cli/tags'

# Version
$this.CurrentState.Version = $Object1[0].name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://awscli.amazonaws.com/AWSCLIV2-$($this.CurrentState.Version).msi"
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
