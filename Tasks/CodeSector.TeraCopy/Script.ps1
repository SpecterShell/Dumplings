$Object1 = Invoke-RestMethod -Uri 'https://codesector.com/updates/teracopy.txt' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Update.Version

# RealVersion
$this.CurrentState.RealVersion = $Object1.Update.ProductVersion

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.Update.URL
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Update.URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.Update.ReleaseDate, 'dd/MM/yyyy', $null).Tostring('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $ReleaseNotesList = [ordered]@{}
      if ($Object1.Update.Contains('Feature')) {
        $ReleaseNotesList['New Features'] = $Object1.Update.GetEnumerator().Where({ $_.Name.StartsWith('Feature') }).ForEach({ $_.Value })
      }
      if ($Object1.Update.Contains('Enhancement')) {
        $ReleaseNotesList['Enhancements'] = $Object1.Update.GetEnumerator().Where({ $_.Name.StartsWith('Enhancement') }).ForEach({ $_.Value })
      }
      if ($Object1.Update.Contains('BugFix')) {
        $ReleaseNotesList['Fixed Bugs'] = $Object1.Update.GetEnumerator().Where({ $_.Name.StartsWith('BugFix') }).ForEach({ $_.Value })
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

    $InstallerFile = Get-TempFile -Uri $InstallerX86.InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    Start-Process -FilePath $InstallerFile -ArgumentList @('/extract') -Wait
    $InstallerFileExtracted = Split-Path -Path $InstallerFile -Parent
    $NestedInstallerFileX86 = Get-ChildItem -Path "${InstallerFileExtracted}\*\TeraCopy.msi" -File | Select-Object -First 1
    $NestedInstallerFileX64 = Get-ChildItem -Path "${InstallerFileExtracted}\*\TeraCopy.x64.msi" -File | Select-Object -First 1

    # InstallerSha256
    $InstallerX86['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerX86['ProductCode'] = $NestedInstallerFileX86 | Read-ProductCodeFromMsi
        UpgradeCode   = $NestedInstallerFileX86 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )

    # InstallerSha256
    $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerX64['ProductCode'] = $NestedInstallerFileX64 | Read-ProductCodeFromMsi
        UpgradeCode   = $NestedInstallerFileX64 | Read-UpgradeCodeFromMsi
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
