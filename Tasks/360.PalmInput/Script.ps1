$Object1 = Invoke-WebRequest -Uri 'https://www.xinshuru.com/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode("//*[@class='win']//*[@class='desc']").InnerText,
  '版本：V(\d+\.\d+\.\d+\.\d+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https:' + $Object1.SelectSingleNode("//*[@class='win']//*[@class='download']").Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode("//*[@class='win']//*[@class='desc']").InnerText,
        '更新日期：(\d{4}/\d{1,2}/\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.xinshuru.com/win_record.html' | ConvertFrom-Html

      $ReleaseNotesObject = $Object2.SelectSingleNode("//*[@class='history' and contains(.//*[@class='latest'], '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $ReleaseNotesObject.SelectSingleNode('.//*[@class="htime"]') | Get-TextContent | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectNodes('.//*[@class="latest"]/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
