$Object1 = Invoke-WebRequest -Uri 'https://www.wmzhe.com/soft-13163.html' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = $Object1.SelectSingleNode('//*[@id="app"]/div[3]/div[1]/div[1]/div[2]/div[1]/ul[1]/li[4]/span[2]').InnerText.Trim()

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download_group"]/li[9]/dl/dd/a').Attributes['href'].Value.Replace('https://', 'http://')
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact($Task.CurrentState.Version, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'http://qxys.hkfree.work/ShowPost.asp?PostID=892' | ConvertFrom-Html

    try {
      $ReleaseNotesNodes = @()
      switch ($Object2.SelectNodes("//*[@class='ForumPostContentText'][1]/node()[starts-with(string(), '$($Task.CurrentState.Version)')]/following-sibling::node()")) {
        ({ $_.Name -eq 'br' -and $_.NextSibling.Name -eq 'br' }) { break }
        Default { $ReleaseNotesNodes += $_ }
      }

      if ($ReleaseNotesNodes) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
