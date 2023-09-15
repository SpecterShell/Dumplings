$Object1 = (Invoke-RestMethod -Uri 'https://params.wps.com/api/map/web/newwpsapk?pttoken=newwinpackages').staticjs.website.wpsnewpackages.downloads | ConvertFrom-Base64 | ConvertFrom-Json

# Installer
$InstallerUrl = $Object1.'500.1001'.downloadurl
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'WPSOffice_([\d\.]+)\.exe').Groups[1].Value

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://api-academy.wps.com/official/whatsnew?platform=pc').data |
      Where-Object -FilterScript { $_.post_excerpt.Contains($Task.CurrentState.Version) }

    try {
      if ($Object2) {
        $Object3 = Invoke-RestMethod -Uri "https://api-academy.wps.com/official/post/detail?slug=$($Object2.more.slug)"
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $Object3.data.published_time | ConvertFrom-UnixTimeSeconds

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3.data.post_content | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = "https://www.wps.com/whatsnew$($Object2.more.slug)/"
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow

        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://www.wps.com/whatsnew/pc/'
        }
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow

      # ReleaseNotesUrl
      $Task.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.wps.com/whatsnew/pc/'
      }
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
