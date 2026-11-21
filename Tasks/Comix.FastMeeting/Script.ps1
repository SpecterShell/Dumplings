# en-US
$Object1 = Invoke-RestMethod -Uri 'https://collect.hst.com/checkUpdate' -Method Post -Body @{
  content = @{
    appkey     = '158f3069a435b314a80bdcb024f8e422'
    curversion = $this.Status.Contains('New') ? '03.42.01.103' : $this.LastState.Version
    lang       = 'en_us'
  } | ConvertTo-Json -Compress
}

if (-not $Object1.hasNewVersion) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.newVersion

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version -replace '(?<=^|\.)0+'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.updateUrl | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.desc | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # zh-CN
      $Object2 = Invoke-RestMethod -Uri 'https://collect.hst.com/checkUpdate' -Method Post -Body @{
        content = @{
          appkey     = '158f3069a435b314a80bdcb024f8e422'
          curversion = $this.Status.Contains('New') ? '03.42.01.103' : $this.LastState.Version
          lang       = 'zh_cn'
        } | ConvertTo-Json -Compress
      }

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.desc | Format-Text
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
