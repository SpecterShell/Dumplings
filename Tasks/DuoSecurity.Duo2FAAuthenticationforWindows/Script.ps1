$Object1 = Invoke-WebRequest -Uri 'https://dl.duosecurity.com/duo-win-login-latest.exe' -Method Head

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Headers.'Content-Disposition'[0], '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://dl.duosecurity.com/duo-win-login-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://dl.duosecurity.com/duo-win-login-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://dl.duosecurity.com/duo-win-login-$($this.CurrentState.Version).exe"
}


switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.msi' '3.msi' '4.msi' | Out-Host
    # x86
    $InstallerFile2 = Join-Path $InstallerFileExtracted '2.msi'
    # ProductCode
    $InstallerX86['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName   = $InstallerFile2 | Read-ProductNameFromMsi
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )
    # x64
    $InstallerFile3 = Join-Path $InstallerFileExtracted '3.msi'
    # ProductCode
    $InstallerX64['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName   = $InstallerFile3 | Read-ProductNameFromMsi
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )
    # arm64
    $InstallerFile4 = Join-Path $InstallerFileExtracted '4.msi'
    # ProductCode
    $InstallerARM64['ProductCode'] = $InstallerFile4 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerARM64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName   = $InstallerFile4 | Read-ProductNameFromMsi
        UpgradeCode   = $InstallerFile4 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object5 = Invoke-WebRequest -Uri 'https://duo.com/docs/rdp-notes' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object5.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
