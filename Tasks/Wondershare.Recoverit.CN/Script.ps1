$this.CurrentState = Invoke-WondershareJsonUpgradeApi -ProductId 4516 -Version '3.0.0' -Locale 'zh-CN'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/data-recovery-64bit_$($this.CurrentState.Version)_full4516.exe"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $this.CurrentState.RealVersion = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
