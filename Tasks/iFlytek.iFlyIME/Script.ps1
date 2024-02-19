$Object1 = Invoke-RestMethod -Uri 'https://godbiao.com/api/getv/' -Headers @{ origin = 'https://srf.xunfei.cn' }

# Version
$this.CurrentState.Version = [regex]::Match($Object1.2 ?? $Object1[2], 'v([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://srf.xunfei.cn/winpc/'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
