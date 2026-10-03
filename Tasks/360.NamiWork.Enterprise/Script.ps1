$Object1 = Invoke-WebRequest -Uri 'https://www.namiwork.cn/'

# The enterprise page hardcodes the installer URLs in its assistant chunk
$Object2 = Invoke-WebRequest -Uri "https://qcdn.zhaomi.cn/assistant/$([regex]::Match($Object1.Content, 'assets/index-[^"''<>]+\.js').Value)"
$Object3 = Invoke-WebRequest -Uri "https://qcdn.zhaomi.cn/assistant/$([regex]::Match($Object2.Content, 'assets/src-[^"''<>]+\.js').Value)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = [regex]::Match($Object3.Content, 'https://sedl\.360tpcdn\.com/se/namiworkent_[\d.]+_setup\.exe').Value
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
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
