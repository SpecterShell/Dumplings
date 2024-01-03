$Object1 = (Invoke-RestMethod -Uri 'https://qidian.qq.com/store/qd_interface/Download.php').data | Where-Object -Property 'FPlatform' -EQ -Value '1'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.FUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.FReleaseTime | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
