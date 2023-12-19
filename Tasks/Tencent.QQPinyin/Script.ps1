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

if ((Compare-Version -ReferenceVersion $Version1 -DifferenceVersion $Version2) -gt 0) {
  # Version
  $this.CurrentState.Version = $Version2

  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Object2.Desp.Replace("`r`r", "`r") | Split-LineEndings | Select-Object -Skip 1 | Format-Text
  }
} else {
  # Version
  $this.CurrentState.Version = $Version1

  # ReleaseTime
  $this.CurrentState.ReleaseTime = [regex]::Match(
    $Object1.SelectSingleNode('//*[@id="banner_box_pinyin"]/div[2]/div[2]/p[2]').InnerText,
    '(\d{4}\.\d{1,2}\.\d{1,2})'
  ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://ime.sogoucdn.com/QQPinyin_Setup_$($this.CurrentState.Version).exe"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    if (-not $this.CurrentState.Locale.Where({ $_.Key -eq 'ReleaseNotes' })) {
      $Object3 = Invoke-RestMethod -Uri 'http://qq.pinyin.cn/js/history_info_pc.js' | Get-EmbeddedJson -StartsFrom 'var pcinfo = ' | ConvertFrom-Json

      try {
        $ReleaseNotes = $Object3.vHistory | Where-Object -FilterScript { $_.version.Contains($this.CurrentState.Version) }
        if ($ReleaseNotes) {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotes.version_features | Format-Text
          }
        } else {
          $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
        }
      } catch {
        $this.Logging($_, 'Warning')
      }
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
