$Object1 = Invoke-RestMethod -Uri 'https://s3.amazonaws.com/sapien/software/UpdateToolData/SapienUpdate.inf' | ConvertFrom-Ini

# Version
$ShortVersion = $Object1.'9BF12014-25F9-4dc2-9313-C2F6C55B872C'.version
$this.CurrentState.Version = $ShortVersion + '.0'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.'9BF12014-25F9-4dc2-9313-C2F6C55B872C'.download64
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://s3.amazonaws.com/sapien/software/UpdateToolData/PowerShell%20Studio%202023.log'

      $ReleaseNotesContent = $Object2.Split("`r`n`r`n").Where({ $_.StartsWith($ShortVersion) }, 'First')
      if ($ReleaseNotesContent) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesContent[0], 'Released: (.+?)\n').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesContent[0].Replace("`r`n`t", ' ') | Split-LineEndings | Select-Object -Skip 1 | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
