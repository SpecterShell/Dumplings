$Object = Invoke-RestMethod -Uri 'https://s3.amazonaws.com/sapien/software/UpdateToolData/SapienUpdate.inf' | ConvertFrom-Ini

# Version
$ShortVersion = $Object.'9BF12014-25F9-4dc2-9313-C2F6C55B872C'.version
$Task.CurrentState.Version = $ShortVersion + '.0'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.'9BF12014-25F9-4dc2-9313-C2F6C55B872C'.download64
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Content = Invoke-RestMethod -Uri 'https://s3.amazonaws.com/sapien/software/UpdateToolData/PowerShell%20Studio%202023.log'

    try {
      $ReleaseNotesContent = $Content.Split("`r`n`r`n") | Where-Object -FilterScript { $_.StartsWith($ShortVersion) }
      if ($ReleaseNotesContent) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesContent, 'Released: (.+?)\n').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesContent.Replace("`r`n`t", ' ') | Split-LineEndings | Select-Object -Skip 1 | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
