$Object1 = (Invoke-RestMethod -Uri 'https://api.cnb.cool/HMCL-dev/HMCL/-/releases' -Headers @{ Accept = 'application/vnd.cnb.api+json'; Authorization = $Global:DumplingsSecret.CNBToken }).Where({ $_.prerelease -eq $true }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') }, 'First')[0].brower_download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://docs.hmcl.net/changelog/dev.html#HMCL-$($this.CurrentState.Version)"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/HMCL-dev/HMCL-docs/HEAD/_changelogs/dev/$($this.CurrentState.Version.Split('.')[0..1] -join '.')/$($this.CurrentState.Version).md" | Convert-MarkdownToHtml

      # Remove the "详细版本介绍" link
      $Object2.SelectNodes('//a[contains(text(), "详细版本介绍")]').ForEach({ $_.Remove() })

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2 | Get-TextContent | Format-Text
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

