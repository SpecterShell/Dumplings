$Object1 = Invoke-WebRequest -Uri 'https://qq.pinyin.cn/wubi/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="banner_box_wubi"]/div[2]/div[2]/p[1]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//*[@id="banner_box_wubi"]/div[1]/a').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//*[@id="banner_box_wubi"]/div[2]/div[2]/p[2]').InnerText,
        '(\d{4}\.\d{1,2}\.\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://qq.pinyin.cn/js/history_info_wb_pc.js' | Get-EmbeddedJson -StartsFrom 'var pcinfo = ' | ConvertFrom-Json

      $ReleaseNotesObject = $Object2.vHistory.Where({ $_.version.Contains($this.CurrentState.Version) }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].version_features | Split-LineEndings | Select-Object -Skip 1 | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
