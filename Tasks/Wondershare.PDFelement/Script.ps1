$this.CurrentState = $Global:DumplingsStorage.WondershareUpgradeInfo['5239']

# Installer
$this.CurrentState.Installer = @(
  [ordered]@{
    Architecture = 'x86'
    InstallerUrl = "https://download.wondershare.com/cbs_down/pdfelement-pro_$($this.CurrentState.Version)_full5239.exe"
  }
  [ordered]@{
    Architecture = 'x64'
    InstallerUrl = "https://download.wondershare.com/cbs_down/pdfelement-pro_64bit_$($this.CurrentState.Version)_full5239.exe"
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
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log('Major version update. The WinGet package needs to be updated', 'Error')
    } else {
      $this.Submit()
    }
  }
}
