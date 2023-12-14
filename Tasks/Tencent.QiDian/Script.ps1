$Object = (Invoke-RestMethod -Uri 'https://qidian.qq.com/store/qd_interface/Download.php').data | Where-Object -Property 'FPlatform' -EQ -Value '1'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object.FUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.FReleaseTime | Get-Date -Format 'yyyy-MM-dd'

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
