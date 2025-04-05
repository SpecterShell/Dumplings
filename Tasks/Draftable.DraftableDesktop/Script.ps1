$Object1 = (Invoke-RestMethod -Uri 'https://dl.draftable.com/desktop/releases.win.json').Assets | Where-Object -FilterScript { $_.Type -eq 'Full' } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = "https://dl.draftable.com/desktop/DraftableDesktopSetup-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = "https://dl.draftable.com/desktop/DraftableDesktopSetup-$($this.CurrentState.Version).msi"
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
