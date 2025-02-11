# # Version
# $this.CurrentState.Version = (Invoke-RestMethod -Uri 'https://onecommander.com/version.txt').Trim()

# # Installer
# $this.CurrentState.Installer += [ordered]@{
#   InstallerUrl = "https://onecommander.com/OneCommanderSetup$($this.CurrentState.Version).msi"
# }

$Object1 = Invoke-WebRequest -Uri 'https://onecommander.com/'

$InstallerName = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, '([\d\.]+)\.msi').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://onecommander.com/' $InstallerName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi
    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
        UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
      }
    )

    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://onecommander.com/releasenotes.txt').RawContentStream)

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String.StartsWith($this.CurrentState.Version -replace '(\.0)+$')) {
          try {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [regex]::Match($String, '\((\d{4}-\d{1,2}-\d{1,2})\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
          } catch {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^\d+(\.\d+)+') {
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
