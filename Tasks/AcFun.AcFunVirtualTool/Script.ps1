$Object1 = Invoke-RestMethod -Uri 'https://api.kuaishouzt.com/rest/zt/appsupport/checkupgrade?appver=0.0.0.0&kpn=ACFUN_APP.LIVE.PC&kpf=WINDOWS_PC'

# Version
$this.CurrentState.Version = $Object1.releaseInfo.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.releaseInfo.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releaseInfo.message | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    # ReleaseNotesUrl
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = $null
    }

    try {
      $Headers = @{ Referer = 'https://livetool.kuaishou.com' }
      $Key = (Invoke-RestMethod -Uri 'https://ytech-ai.kuaishou.cn/ytech/api/register' -Headers $Headers -SkipHeaderValidation).Split(':')[0]
      $Object2 = Invoke-RestMethod -Uri "https://ytech-ai.kuaishou.cn/ytech/api/virtual/reconstruct/record?api_key=${Key}&timestamp=$([System.DateTimeOffset]::Now.ToUnixTimeMilliseconds())" -Headers $Headers -SkipHeaderValidation

      $ReleaseNotesUrlNode = $Object2.data.data.Where({ $_.iconText.Contains($this.CurrentState.Version.Split('.')[0..1] -join '.') }, 'First')
      if ($ReleaseNotesUrlNode) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrlNode[0].link
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
