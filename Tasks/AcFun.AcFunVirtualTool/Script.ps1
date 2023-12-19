$Object1 = Invoke-RestMethod -Uri 'https://api.kuaishouzt.com/rest/zt/appsupport/checkupgrade?appver=0.0.0.0&kpn=ACFUN_APP.LIVE.PC&kpf=WINDOWS_PC'

# Version
$this.CurrentState.Version = $Object1.releaseInfo.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.releaseInfo.downloadUrl
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.releaseInfo.message | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Headers = @{
      Referer = 'https://livetool.kuaishou.com'
    }
    $Key = (Invoke-RestMethod -Uri 'https://ytech-ai.kuaishou.cn/ytech/api/register' -Headers $Headers -SkipHeaderValidation).Split(':')[0]
    $Object2 = Invoke-RestMethod -Uri "https://ytech-ai.kuaishou.cn/ytech/api/virtual/reconstruct/record?api_key=${Key}&timestamp=$([System.DateTimeOffset]::Now.ToUnixTimeMilliseconds())" -Headers $Headers -SkipHeaderValidation

    try {
      $ReleaseNotesUrl = $Object2.data.data.Where({ $_.iconText.Contains([regex]::Match($this.CurrentState.Version, '(\d+\.\d+)').Groups[1].Value) })[0].link
      if ($ReleaseNotesUrl) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl
        }
      } else {
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $null
        }
      }
    } catch {
      $this.Logging($_, 'Warning')
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
