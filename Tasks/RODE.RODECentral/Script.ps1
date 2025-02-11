$Object1 = Invoke-RestMethod -Uri 'https://update.rode.com/rode-devices-manifest.json'

# Version
$this.CurrentState.Version = $Object1.'rode-central-manifest'.windows.'main-version'.'update-version'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://' + $Object1.'rode-central-manifest'.windows.'main-version'.'download-URL'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://rode.com/en/release-notes/rode-central' | ConvertFrom-Html
      $Object3 = $Object2.SelectSingleNode('//rode-release-notes').Attributes[':release-notes-data'].DeEntitizeValue | ConvertFrom-Json

      $ReleaseNotesObject = $Object3.Where({ $_.version.Contains($this.CurrentState.Version) }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesObject[0].text, '([a-zA-Z]+\W+\d{1,2}\W+20\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesObject[0].note | ConvertFrom-Json) | ForEach-Object -Process {
            $Type = switch ($_.type) {
              'improvement' { '[Improvement] ' }
              'bug-fix' { '[Bug Fix] ' }
              'new-feature' { '[New Feature] ' }
            }
            "${Type}$($_.note)"
          } | Format-Text
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
