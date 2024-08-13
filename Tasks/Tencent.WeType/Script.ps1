$Object1 = Invoke-RestMethod -Uri 'https://z.weixin.qq.com/web/api/app_info'

$InstallerUrl = $Object1.data.windows.latest

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri 'https://z.weixin.qq.com/web/change-log/' | Get-EmbeddedJson -StartsFrom 'window.injectData=' | ConvertFrom-Json

      $ShortVersion = $Version.Split('.')[0..2] -join '.'

      $ReleaseNotesObject = $Object2.appChangelog.Where({ $_.platform -eq 4 -and $_.version -eq $ShortVersion }, 'First')
      if ($ReleaseNotesObject) {
        $ReleaseNotes = $ReleaseNotesObject.content_html | ConvertFrom-Html | Get-TextContent

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes -replace '该版本主要更新\n' | Format-Text
        }
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = "https://z.weixin.qq.com/web/change-log/$($ReleaseNotesObject.id)"
        }

        $ReleaseTime = $ReleaseNotesObject.release_date | ConvertFrom-UnixTimeSeconds
        $TimeZoneInfo = [System.TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time')
        $this.CurrentState.ReleaseTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($ReleaseTime, $TimeZoneInfo) | Get-Date -Format 'yyyy-MM-dd'
      }
    }
    catch {
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
