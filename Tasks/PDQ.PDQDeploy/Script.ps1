$Object1 = Invoke-RestMethod -Uri 'https://services.pdq.tools/function/update-info' -Method Post -Body (
  @{
    ReleaseType      = 'Release'
    InstalledVersion = $this.LastState.Contains('Version') ? $this.LastState.Version : '19.3.538.0'
    Product          = 'Deploy'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.buildDate

      $Object2 = [System.IO.StringReader]::new($Object1.highlights)
      while ($Object2.Peek() -ne -1) {
        $String = $Object2.ReadLine()
        if ($String.Contains("Release $($this.CurrentState.Version)")) {
          try {
            # ReleaseTime
            $this.CurrentState.ReleaseTime ??= [regex]::Match($String, '(20\d{1,2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
          } catch {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          $null = $Object2.ReadLine()
          break
        }
      }
      if ($Object2.Peek() -ne -1) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while ($Object2.Peek() -ne -1) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^-+$') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.msi' | Out-Host
    $InstallerFile = Join-Path $InstallerFileExtracted '2.msi'
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile | Read-UpgradeCodeFromMsi
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
