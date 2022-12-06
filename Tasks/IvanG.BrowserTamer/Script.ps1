$Prefix = 'https://www.aloneguid.uk/projects/bt/'

$Object = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

# Installer
$InstallerUrl = $Prefix + $Object.SelectSingleNode('//*[@id="page"]/main/div/ul[1]/li[1]/a[1]').Attributes['href'].Value
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+)').Groups[1].Value

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Content = (Invoke-RestMethod -Uri 'https://www.aloneguid.uk/projects/bt/bin/log.txt').Split("`n`n") |
      Where-Object -FilterScript { $_.Contains($Task.CurrentState.Version) } |
      Split-LineEndings

    try {
      if ($Content) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match($Content[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Content | Select-Object -Skip 1 | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
