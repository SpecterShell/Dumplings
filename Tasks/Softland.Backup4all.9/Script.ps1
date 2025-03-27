$Object1 = Invoke-RestMethod -Uri 'https://www.backup4all.com/updatecheck/AAAA-BBBB-CCCC-DDDD-EEEE-FFFF-B4A9-3333'

if ($Object1.BACKUP4ALL.BUILDS.BUILD[0].MAJORVER -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
  throw "The WinGet package needs to be updated for the major version $($Object1.BACKUP4ALL.BUILDS.BUILD[0].MAJORVER)"
}

# Version
$this.CurrentState.Version = "$($Object1.BACKUP4ALL.BUILDS.BUILD[0].MAJORVER).$($Object1.BACKUP4ALL.BUILDS.BUILD[0].MINORVER).$($Object1.BACKUP4ALL.BUILDS.BUILD[0].BUILD)"

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = $Object1.BACKUP4ALL.DOWNLOAD.LINK
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  # InstallerUrl  = "https://www.backup4all.com/download/setup/b4asetup-$($this.CurrentState.Version.Split('.')[0]).msi"
  InstallerUrl  = 'https://www.backup4all.com/download/setup/b4asetup.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.BACKUP4ALL.BUILDS.BUILD[0].DATE, 'dd-MM-yyyy', $null) | Get-Date -Format 'yyyy-MM-dd'

      $ReleaseNotes = @()
      if ($Object1.BACKUP4ALL.BUILDS.BUILD[0].SelectSingleNode('UPDATES')) {
        $ReleaseNotes += $Object1.BACKUP4ALL.BUILDS.BUILD[0].UPDATES.UPDATE
      }
      if ($Object1.BACKUP4ALL.BUILDS.BUILD[0].SelectSingleNode('FIXES')) {
        $ReleaseNotes += $Object1.BACKUP4ALL.BUILDS.BUILD[0].FIXES.FIX
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

    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
