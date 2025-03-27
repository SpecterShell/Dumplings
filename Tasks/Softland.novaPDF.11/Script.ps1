$Object1 = Invoke-RestMethod -Uri 'https://www.novapdf.com/update-check.html?key=AAAA-BBBB-CCCC-DDDD-EEEE-FFFF-BD11-A111'

if ($Object1.NOVAPDF.BUILDS.BUILD[0].MAJORVER -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
  throw "The WinGet package needs to be updated for the major version $($Object1.NOVAPDF.BUILDS.BUILD[0].MAJORVER)"
}

# Version
$this.CurrentState.Version = "$($Object1.NOVAPDF.BUILDS.BUILD[0].MAJORVER).$($Object1.NOVAPDF.BUILDS.BUILD[0].MINORVER).$($Object1.NOVAPDF.BUILDS.BUILD[0].BUILD)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.NOVAPDF.DOWNLOAD.LINK
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.NOVAPDF.BUILDS.BUILD[0].DATE, 'dd-MM-yyyy', $null) | Get-Date -Format 'yyyy-MM-dd'

      $ReleaseNotes = @()
      if ($Object1.NOVAPDF.BUILDS.BUILD[0].SelectSingleNode('UPDATES')) {
        $ReleaseNotes += $Object1.NOVAPDF.BUILDS.BUILD[0].UPDATES.UPDATE
      }
      if ($Object1.NOVAPDF.BUILDS.BUILD[0].SelectSingleNode('FIXES')) {
        $ReleaseNotes += $Object1.NOVAPDF.BUILDS.BUILD[0].FIXES.FIX
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
