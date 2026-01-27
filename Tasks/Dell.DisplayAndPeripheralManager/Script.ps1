$Object1 = Invoke-WebRequest -Uri 'https://www.dell.com/support/driver/en-us/ips/api/driverlist/packdriversbyproduct?productcode=dell-display-peripheral-manager&oscode=WT64A&lob=Software' -Headers @{
  'Accept'           = '*/*'
  'X-Requested-With' = 'XMLHttpRequest'
}
$Shift = -3
$Object2 = $Object1.Content.ToCharArray() | ForEach-Object -Process {
  if ($_ -ge 'A' -and $_ -le 'Z') {
    [char](($_ - 65 + $Shift + 26) % 26 + 65)
  } elseif ($_ -ge 'a' -and $_ -le 'z') {
    [char](($_ - 97 + $Shift + 26) % 26 + 97)
  } else {
    [char]$_
  }
} | Join-String -Separator '' | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.DriverListData[0].FileFrmtInfo.HttpFileLocation
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.DriverListData[0].ReleaseDateValue.ToUniversalTime()
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
