$Object1 = Invoke-WebRequest -Uri 'https://benchmate.org/'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'BenchMate\W+(\d+(\.\d+)+)').Groups[1].Value -replace '^(\d+\.\d+)$', '$1.0' # Pad the version with only two digits to three digits

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://dl.benchmate.org/bm-$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerFileExtracted = New-TempFolder
    Start-Process -FilePath $InstallerFile -ArgumentList @('/extract', $InstallerFileExtracted) -Wait
    $InstallerFile2 = Join-Path $InstallerFileExtracted '*' 'bm.msi' | Get-Item -Force | Select-Object -First 1
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://benchmate.org/changelog/all' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[contains(@id, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}\.\d{1,2}\.20\d{2})').Groups[1].Value,
          'dd.MM.yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
