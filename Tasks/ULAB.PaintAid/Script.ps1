$Object1 = Invoke-RestMethod -Uri 'http://pa.udongman.cn/index.php/upgrade/'

# Version
$this.CurrentState.Version = "$($Object1.updater.pa_mversion).$($Object1.updater.pa_subversion)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.updater.TypeWin.package_url + $Object1.updater.TypeWin.package.name | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($InstallerUrl, '(\d{8})').Groups[1].Value,
        'yyyyMMdd',
        $null
      ).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri "http://pa.udongman.cn/index.php/v2/version/detail?version=$($this.CurrentState.Version)"

      # ReleaseNotes (zh-CN)
      if ($Object2.data) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.data.data.func_description | Format-Text
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
