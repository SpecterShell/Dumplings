# Download
$Object1 = Invoke-WebRequest -Uri 'http://qq.pinyin.cn/' | ConvertFrom-Html
$Version1 = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="banner_box_pinyin"]/div[2]/div[2]/p[1]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Upgrade
$Object2 = Invoke-RestMethod -Uri 'http://config.android.qqpy.sogou.com/update?fr=pypc' -Method Post -Body (
  @{
    'CSoftID'     = 14
    'CVer'        = '6.2.5507.400'
    'Cmd'         = 1
    'GUID'        = '000000000'
    'TriggerMode' = 4
  } | ConvertTo-Json -Compress
)
$Version2 = $Object2.NewVer

# Version
$this.CurrentState.Version = [Versioning]$Version1 -lt [Versioning]$Version2 ? $Version2 : $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://ime.sogoucdn.com/QQPinyin_Setup_$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ([Versioning]$Version1 -lt [Versioning]$Version2) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.Desp.Replace("`r`r", "`r") | Split-LineEndings | Select-Object -Skip 1 | Format-Text
        }
      } else {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $Object1.SelectSingleNode('//*[@id="banner_box_pinyin"]/div[2]/div[2]/p[2]').InnerText,
          '(\d{4}\.\d{1,2}\.\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $Object3 = Invoke-RestMethod -Uri 'http://qq.pinyin.cn/js/history_info_pc.js' | Get-EmbeddedJson -StartsFrom 'var pcinfo = ' | ConvertFrom-Json

        $ReleaseNotesObject = $Object3.vHistory.Where({ $_.version.Contains($this.CurrentState.Version) }, 'First')
        if ($ReleaseNotesObject) {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject[0].version_features | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
        }
      }
    } catch {
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
