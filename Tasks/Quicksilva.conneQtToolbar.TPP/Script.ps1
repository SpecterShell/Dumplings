$Object1 = Invoke-RestMethod -Uri "https://software.quicksilva.info/live-tpp-toolbar/update?version=$($this.Status.Contains('New') ? '1.5.0.861' : $this.LastState.Version)"

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.location
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
