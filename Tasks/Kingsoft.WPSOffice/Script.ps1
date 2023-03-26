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
    $Object2 = Invoke-WebRequest -Uri 'https://www.wps.com/whatsnew/pc/' | ConvertFrom-Html

    try {
      if ($Object2.SelectSingleNode('//*[@id="root"]/div[2]/div/div[1]/div[1]/a/div/p[2]').InnerText.Contains($Task.CurrentState.Version)) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $Object2.SelectSingleNode('//*[@id="root"]/div[2]/div/div[1]/div[1]/a/div/p[1]/span[1]').InnerText,
          '(\d{1,2}/\d{1,2}/\d{4})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('//*[@id="root"]/div[2]/div/div[3]/div/*[position()>1]') | Get-TextContent | Format-Text
        }

        try {
          $ReleaseNotesUrl = "https://www.wps.com/whatsnew/pc/$($Task.CurrentState.ReleaseTime.Replace('-',''))/"
          Invoke-WebRequest -Uri $ReleaseNotesUrl | Out-Null
          # ReleaseNotesUrl
          $Task.CurrentState.Locale += [ordered]@{
            Key   = 'ReleaseNotesUrl'
            Value = $ReleaseNotesUrl
          }
        } catch {
          Write-Host -Object "Task $($Task.Name): Cannot reach $($ReleaseNotesUrl), fallback to https://www.wps.com/whatsnew/pc/" -ForegroundColor Yellow
          # ReleaseNotesUrl
          $Task.CurrentState.Locale += [ordered]@{
            Key   = 'ReleaseNotesUrl'
            Value = 'https://www.wps.com/whatsnew/pc/'
          }
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
