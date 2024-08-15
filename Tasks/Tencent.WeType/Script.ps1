$Object1 = Invoke-RestMethod -Uri 'https://z.weixin.qq.com/web/api/app_info'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.data.windows.official
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'WeTypeSetup_(\d+(?:\.\d+){3,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # ReleaseNotesUrl
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = 'https://z.weixin.qq.com/web/change-log/'
    }

    try {
      $Object2 = ((Invoke-WebRequest -Uri 'https://z.weixin.qq.com/').Content | Get-EmbeddedJson -StartsFrom 'window.injectData=' | ConvertFrom-Json).appChangelog.Where({ $_.platform -eq 4 -and $_.version -eq ($this.CurrentState.Version.Split('.')[0..2] -join '.') }, 'First')

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].release_date | ConvertFrom-UnixTimeSeconds

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].content_html | ConvertFrom-Html | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = "https://z.weixin.qq.com/web/change-log/$($Object2[0].id)"
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
