$Object1 = Invoke-RestMethod -Uri 'https://www.fbackup.com/updatecheck/FBC9-D3E3-65CD-4139-850F-94E0-6A63-A238'

# Version
$this.CurrentState.Version = "$($Object1.FBACKUP.BUILDS.BUILD[0].MAJORVER).$($Object1.FBACKUP.BUILDS.BUILD[0].MINORVER).$($Object1.FBACKUP.BUILDS.BUILD[0].BUILD)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.FBACKUP.DOWNLOAD.LINK
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.FBACKUP.BUILDS.BUILD[0].DATE, 'dd-MM-yyyy', $null) | Get-Date -Format 'yyyy-MM-dd'

      $ReleaseNotes = @()
      if ($Object1.FBACKUP.BUILDS.BUILD[0].SelectSingleNode('UPDATES')) {
        $ReleaseNotes += $Object1.FBACKUP.BUILDS.BUILD[0].UPDATES.UPDATE
      }
      if ($Object1.FBACKUP.BUILDS.BUILD[0].SelectSingleNode('FIXES')) {
        $ReleaseNotes += $Object1.FBACKUP.BUILDS.BUILD[0].FIXES.FIX
      }
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes | Format-Text
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
    if ($this.CurrentState.Version.Split('.')[0] -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log("The WinGet package needs to be updated to the version $($this.CurrentState.Version.Split('.')[0])", 'Error')
    } else {
      $this.Submit()
    }
  }
}
