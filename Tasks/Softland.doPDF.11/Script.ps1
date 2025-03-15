$Object1 = Invoke-RestMethod -Uri 'https://www.dopdf.com/update-check.html?key=141B-80AD-17E2-11E9-97B7-0CC4-7AC3-5A11'

# Version
$this.CurrentState.Version = "$($Object1.DOPDF.BUILDS.BUILD[0].MAJORVER).$($Object1.DOPDF.BUILDS.BUILD[0].MINORVER).$($Object1.DOPDF.BUILDS.BUILD[0].BUILD)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.DOPDF.DOWNLOAD.LINK
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.DOPDF.BUILDS.BUILD[0].DATE, 'dd-MM-yyyy', $null) | Get-Date -Format 'yyyy-MM-dd'

      $ReleaseNotes = @()
      if ($Object1.DOPDF.BUILDS.BUILD[0].SelectSingleNode('UPDATES')) {
        $ReleaseNotes += $Object1.DOPDF.BUILDS.BUILD[0].UPDATES.UPDATE
      }
      if ($Object1.DOPDF.BUILDS.BUILD[0].SelectSingleNode('FIXES')) {
        $ReleaseNotes += $Object1.DOPDF.BUILDS.BUILD[0].FIXES.FIX
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
    $this.Submit()
  }
}
