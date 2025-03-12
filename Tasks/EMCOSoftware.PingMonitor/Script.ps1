$Object1 = Invoke-RestMethod -Uri 'https://storage.emcosoftware.com/autoupdate/pingmonitor/MajorUpdate.xml'
$Object2 = Invoke-RestMethod -Uri "https://storage.emcosoftware.com/autoupdate/pingmonitor/v$($Object1.ROOT.UPDATEENTRY.VERSION)/Update.xml"

# Version
$this.CurrentState.Version = $Object2.ROOT.UPDATEENTRY[0].VERSION

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.ROOT.SETUP
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $ReleaseNotes = [System.Text.StringBuilder]::new()
      if ($Object2.ROOT.UPDATEENTRY[0].CHANGE.TYPE -contains 'NewFeature') {
        $ReleaseNotes = $ReleaseNotes.AppendLine('New features:')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object2.ROOT.UPDATEENTRY[0].CHANGE.Where({ $_.TYPE -eq 'NewFeature' }).COMMENT | ConvertTo-UnorderedList))
      }
      if ($Object2.ROOT.UPDATEENTRY[0].CHANGE.TYPE -contains 'Improvement') {
        $ReleaseNotes = $ReleaseNotes.AppendLine('Improvements:')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object2.ROOT.UPDATEENTRY[0].CHANGE.Where({ $_.TYPE -eq 'Improvement' }).COMMENT | ConvertTo-UnorderedList))
      }
      if ($Object2.ROOT.UPDATEENTRY[0].CHANGE.TYPE -contains 'BugFix') {
        $ReleaseNotes = $ReleaseNotes.AppendLine('Resolved Issues:')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object2.ROOT.UPDATEENTRY[0].CHANGE.Where({ $_.TYPE -eq 'BugFix' }).COMMENT | ConvertTo-UnorderedList))
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes.ToString() | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }


    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd '-t#' -o"${InstallerFileExtracted}" $InstallerFile '6.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '6.msi'
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

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
