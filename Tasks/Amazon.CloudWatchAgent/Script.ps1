# Version
$this.CurrentState.Version = (Invoke-WebRequest -Uri 'https://amazoncloudwatch-agent.s3.amazonaws.com/info/latest/CWAGENT_VERSION' | Read-ResponseContent).Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://amazoncloudwatch-agent.s3.amazonaws.com/windows/amd64/$($this.CurrentState.Version)/amazon-cloudwatch-agent.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://amazoncloudwatch-agent.s3.amazonaws.com/info/latest/RELEASE_NOTES').RawContentStream)
      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String.Contains([regex]::Match($this.CurrentState.Version, '^(\d+\.\d+\.\d+)').Groups[1].Value)) {
          if ($String -match '(20\d{2}-\d{1,2}-\d{1,2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } else {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          $null = $Object2.ReadLine()
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^=+$') {
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
