# Installer
$this.CurrentState.Installer += [ordered]@{
  # InstallerUrl = Get-RedirectedUrl -Uri 'https://download.quark.cn/download/quarkpc?platform=pc&ch=pcquark@app_downloader_fail'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://download.quark.cn/download/quarkpc?platform=pc&ch=pcquark@homepage_oficial'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'V(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

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
