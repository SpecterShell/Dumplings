$Object1 = Invoke-WebRequest -Uri 'https://www.wmzhe.com/soft-13163.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('//*[@id="app"]/div[3]/div[1]/div[1]/div[2]/div[1]/ul[1]/li[4]/span[2]').InnerText.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download_group"]/li[9]/dl/dd/a').Attributes['href'].Value.Replace('https://', 'http://')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact($this.CurrentState.Version, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-WebRequest -Uri 'http://qxys.hkfree.work/ShowPost.asp?PostID=892' | ConvertFrom-Html

      $ReleaseNotesNodes = @()
      switch ($Object2.SelectNodes("//*[@class='ForumPostContentText'][1]/node()[starts-with(string(), '$($this.CurrentState.Version)')]/following-sibling::node()")) {
        ({ $_.Name -eq 'br' -and $_.NextSibling.Name -eq 'br' }) { break }
        Default { $ReleaseNotesNodes += $_ }
      }
      if ($ReleaseNotesNodes) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
