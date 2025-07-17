$Object1 = Invoke-WebRequest -Uri 'https://www.myworkdrive.com/download' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//input[contains(@value, ".exe")]').Attributes['value'].Value
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:-\d+)+)').Groups[1].Value.Replace('-', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'Files\MyWorkDrive.Installer.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'MyWorkDrive.Installer.msi'
    # Version
    $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromMsi
    # ProductCode
    $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.myworkdrive.com/kb/articles/windows-client-release-notes' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//text()[contains(., 'MyWorkDrive Windows Client $($this.CurrentState.Version)') or contains(., 'MyWorkDrive Windows Client $($this.CurrentState.Version.Replace('.', '-'))')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
