$Task.CurrentState = $LocalStorage.WondershareUpgradeInfo['5239']

# Installer
$Task.CurrentState.Installer = @(
  [ordered]@{
    Architecture = 'x86'
    InstallerUrl = "https://download.wondershare.com/cbs_down/pdfelement-pro_$($Task.CurrentState.Version)_full5239.exe"
  }
  [ordered]@{
    Architecture = 'x64'
    InstallerUrl = "https://download.wondershare.com/cbs_down/pdfelement-pro_64bit_$($Task.CurrentState.Version)_full5239.exe"
  }
)

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
