$Object1 = Invoke-RestMethod -Uri 'https://prod.download.desktop.kiro.dev/stable/metadata-win32-x64-user-stable.json'

# Version
$this.CurrentState.Version = $Object1.currentRelease

$Object2 = $Object1.releases.Where({ $_.updateTo.version -eq $this.CurrentState.Version }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object2.updateTo.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.updateTo.pub_date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://kiro.dev/changelog/index' | ConvertFrom-Html

      $ReleaseNotesObject = $Object3.SelectSingleNode("//article[contains(./div[1]/div[1]/span, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesObject) {
        # Remove "Learn more" links
        $ReleaseNotesObject.SelectNodes('.//a[contains(text(), "Learn more")]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectNodes('./div[1]/following-sibling::node()') | Get-TextContent | Format-Text
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
