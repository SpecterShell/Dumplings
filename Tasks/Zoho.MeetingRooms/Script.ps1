# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://meeting.zoho.com/rooms?os=windows' -Method GET -UserAgent $DumplingsBrowserUserAgent
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri (Join-Uri $this.CurrentState.Installer[0].InstallerUrl 'latest.yml') | ConvertFrom-Yaml

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.releaseDate | Get-Date -AsUTC
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
