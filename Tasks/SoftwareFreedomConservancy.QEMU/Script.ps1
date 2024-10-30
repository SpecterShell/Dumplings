$Object1 = Invoke-WebRequest -Uri 'https://qemu.weilnetz.de/?F=0'
$Object2 = [regex]::Match($Object1.Content, '<strong>(?<Date>\d{4}-\d{1,2}-\d{1,2})</strong>: New QEMU installer \((?<Version>\d+(?:\.\d+)+)\)')
$Object3 = $Object2.Groups['Date'].Value | Get-Date

# Version
$this.CurrentState.Version = $Object2.Groups['Version'].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://qemu.weilnetz.de/w64/$($Object3.ToString('yyyy'))/qemu-w64-setup-$($Object3.ToString('yyyyMMdd')).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.ToString('yyyy-MM-dd')

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://wiki.qemu.org/ChangeLog/$($this.CurrentState.Version.Split('.')[0..1] -join '.')"
      }
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
