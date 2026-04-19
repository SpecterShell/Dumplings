$Object1 = Invoke-RestMethod -Uri 'https://rekordbox.com/hidden2/rb7_release/apl/check_updater.php' -Method Post -Body @{
  UP_NAME    = 'rekordbox4'
  OS_TYPE    = 'Windows'
  OS_VERSION = '10-64-64'
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1, 'UP_VER=([^;]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = [regex]::Match($Object1, 'UP_URL=([^;]+)').Groups[1].Value
  ProductCode = "Pioneer rekordbox $($this.CurrentState.Version)"
}

# RealVersion
$this.CurrentState.RealVersion = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'x64_(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://rekordbox.com/support/releasenote/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//li[contains(@class, 'rb-g-list-item') and contains(./h2, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./*[contains(@id, "content")]') | Get-TextContent | Format-Text
        }

        # ReleaseTime
        if ($ReleaseNotesNode.SelectSingleNode('./h2') -and [regex]::Match($ReleaseNotesNode.SelectSingleNode('./h2').InnerText, '(20\d{2}\W+\d{1,2}\W+\d{1,2})').Groups[1].Value) {
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
        } else {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
