# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrls -Uri 'https://download.10jqka.com.cn/index/download/id/84/' -Method GET | Select-Object -Last 1
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'insoft_?(\d+(?:\.\d+){2,})').Groups[1].Value

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
