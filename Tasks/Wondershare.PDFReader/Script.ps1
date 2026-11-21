$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['13142']

# Installer
$this.CurrentState.Installer = @(
  [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $this.CurrentState.Installer[0].InstallerUrl.Replace('_64bit', '')
  }
  [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $this.CurrentState.Installer[0].InstallerUrl
  }
)

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
