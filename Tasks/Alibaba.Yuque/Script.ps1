$Object = Invoke-RestMethod -Uri 'https://app.nlark.com/yuque-desktop/v5/public/windows-stable.json'

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.files.Where({ $_.updateType -eq 'package' }).url
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.releaseNotes | Format-Text | ConvertTo-UnorderedList
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $EdgeDriver = Get-EdgeDriver
    $EdgeDriver.Navigate().GoToUrl('https://www.yuque.com/yuque/yuque-desktop/changelog')

    try {
      $Object2 = $EdgeDriver.ExecuteScript('return window.appData', $null)
      $ReleaseNotesUrlObject = $Object2.book.toc.Where({ $_.title.Contains($Task.CurrentState.Version) })
      if ($ReleaseNotesUrlObject) {
        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://www.yuque.com/yuque/yuque-desktop/' + $ReleaseNotesUrlObject.url
        }

        # $Object3 = Invoke-RestMethod -Uri "https://www.yuque.com/api/docs/$($ReleaseNotesUrlObject.url)?book_id=$($Object2.doc.book_id)"
        # $Task.CurrentState.ReleaseTime = [regex]::Match(
        #   $Object3.data.description,
        #   '发布时间[:：]\s*(\d{4}\.\d{1,2}\.\d{1,2})'
        # ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotesUrl and ReleaseTime for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://www.yuque.com/yuque/yuque-desktop/'
        }
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
