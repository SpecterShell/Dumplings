$Object1 = Invoke-RestMethod -Uri 'https://ugit.qq.com/downloads/ugit_public/RELEASES'

# Version
$this.CurrentState.Version = [regex]::Match($Object1, 'UGit-(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://ugit.qq.com/downloads/ugit_public/UGitSetup.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://ugit.qq.com/changelog.json'

      $ReleaseNotesObject = $Object2.Where({ $_.version -eq "v$($this.CurrentState.Version)" }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesObject.pub_date | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.notes | Format-Text
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
