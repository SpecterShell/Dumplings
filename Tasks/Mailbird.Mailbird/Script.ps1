$Object1 = (Invoke-RestMethod -Uri 'https://download.getmailbird.com/installers/versions/updates_v3.txt' | ConvertFrom-Ini).GetEnumerator().Where({ $_.Name.StartsWith('Mailbird') }, 'First')[0].Value

# Version
$this.CurrentState.Version = $Object1.Version

# RealVersion
$this.CurrentState.RealVersion = $Object1.ProductVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.URL | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.ReleaseDate, 'dd/MM/yyyy', $null).Tostring('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $ReleaseNotesList = [ordered]@{}
      if ($Object1.Contains('Feature')) {
        $ReleaseNotesList['New Features'] = $Object1.GetEnumerator().Where({ $_.Name.StartsWith('Feature') }).ForEach({ $_.Value })
      }
      if ($Object1.Contains('Enhancement')) {
        $ReleaseNotesList['Enhancements'] = $Object1.GetEnumerator().Where({ $_.Name.StartsWith('Enhancement') }).ForEach({ $_.Value })
      }
      if ($Object1.Contains('BugFix')) {
        $ReleaseNotesList['Fixed Bugs'] = $Object1.GetEnumerator().Where({ $_.Name.StartsWith('BugFix') }).ForEach({ $_.Value })
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesList.GetEnumerator().ForEach({ "$($_.Name)`n$($_.Value | ConvertTo-UnorderedList)" }) -join "`n`n" | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    Start-Process -FilePath $InstallerFile -ArgumentList @('/extract') -Wait
    $NestedInstallerFileRoot = Split-Path -Path $InstallerFile -Parent
    $NestedInstallerFile = Get-ChildItem -Path "${NestedInstallerFileRoot}\*\MailbirdSetup.x64.msi" -File | Select-Object -First 1

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $NestedInstallerFile | Read-ProductCodeFromMsi
        UpgradeCode   = $NestedInstallerFile | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
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
