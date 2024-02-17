$this.CurrentState = $LocalStorage.WondershareUpgradeInfo['13143']

# Installer
$this.CurrentState.Installer = @(
  [ordered]@{
    Architecture = 'x86'
    InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfreader_$($this.CurrentState.Version)_full13143.exe"
  }
  [ordered]@{
    Architecture = 'x64'
    InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfreader_64bit_$($this.CurrentState.Version)_full13143.exe"
  }
)

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
