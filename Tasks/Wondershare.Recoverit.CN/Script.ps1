$this.CurrentState = Invoke-WondershareJsonUpgradeApi -ProductId 4516 -Version '3.0.0' -Locale 'zh-CN'

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = "https://cc-download.wondershare.cc/cbs_down/data-recovery-64bit_$($this.CurrentState.Version)_full4516.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
