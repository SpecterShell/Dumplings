$Task.CurrentState = $LocalStorage.WondershareUpgradeInfo['13143']

# Installer
$Task.CurrentState.Installer = @(
  [ordered]@{
    Architecture = 'x86'
    InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfreader_$($Task.CurrentState.Version)_full13143.exe"
  }
  [ordered]@{
    Architecture = 'x64'
    InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/pdfreader_64bit_$($Task.CurrentState.Version)_full13143.exe"
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
