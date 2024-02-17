$Object1 = Invoke-RestMethod -Uri 'https://godbiao.com/api/getv/' -Headers @{ origin = 'https://srf.xunfei.cn' }

# Version
$this.CurrentState.Version = [regex]::Match($Object1.2 ?? $Object1[2], 'v([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://srf.xunfei.cn/winpc/'
}

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
