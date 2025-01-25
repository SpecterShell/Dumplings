$Object1 = $Global:DumplingsStorage.SeewoApps['ExceedShare']

# Version
$this.CurrentState.Version = $Object1.softInfos.Where({ $_.useSystem -eq 1 -and $_.useType -eq 4 }, 'First')[0].softVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.softInfos.Where({ $_.useSystem -eq 1 -and $_.useType -eq 4 }, 'First')[0].downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(20\d{12})').Groups[1].Value,
        'yyyyMMddHHmmss',
        $null
      ) | ConvertTo-UtcDateTime -Id 'China Standard Time'
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
