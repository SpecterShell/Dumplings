$Object1 = (Invoke-RestMethod -Uri 'https://qidian.qq.com/store/qd_interface/Download.php').data.Where({ $_.FPlatform -eq '1' }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.FUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.FReleaseTime | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
