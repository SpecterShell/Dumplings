$Object1 = Invoke-WebRequest -Uri 'https://rkward.kde.org/RKWard_on_Windows.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('/html/body/main/ul[1]/li/text()[1]').InnerText, 'RKWard (.+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('/html/body/main/ul[1]/li/a').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayVersion = $InstallerFile | Read-ProductVersionFromExe
      }
    )

    try {
      $Object2 = ((Invoke-RestMethod -Uri 'https://invent.kde.org/education/rkward/-/raw/master/ChangeLog') -split '\s+--- ').Where({ $_.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        $ReleaseNotes = $Object2[0] | Split-LineEndings
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotes[0], '([a-zA-Z]+-\d{1,2}-\d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes | Select-Object -Skip 1 | Format-Text
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
