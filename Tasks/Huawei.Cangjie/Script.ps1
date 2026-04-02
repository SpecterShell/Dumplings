$Prefix = 'https://cangjie-lang.cn/download'
$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html
$Prefix = Join-Uri $Prefix $Object1.SelectSingleNode('//div[@class="download-version-item" and contains(.//div[@class="download-version-item-n"], "LTS Version")]//a').Attributes['href'].Value
$Object2 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html
$Filename = $Object2.SelectSingleNode("//div[contains(@class, 'ivu-col') and contains(text(), '.exe')]").InnerText.Trim()
$Object3 = Invoke-RestMethod -Uri $Object2.SelectSingleNode('//script[contains(@src, "version") and contains(@src, ".js")]').Attributes['src'].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix ([regex]::Match($Object3, "url:`"([^`"]+$([regex]::Escape($Filename))[^`"]+?)`"").Groups[1].Value)
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('//div[@class="subpage-content-time"]').InnerText, '(20\d{2}/\d{1,2}/\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = Join-Uri $Prefix $Object2.SelectSingleNode('//a[contains(., "版本说明")]').Attributes['href'].Value
      }

      $Object4 = Invoke-WebRequest -Uri ('https://docs.cangjie-lang.cn/docs' + [System.Web.HttpUtility]::ParseQueryString(([uri]$ReleaseNotesUrl).Query)['url']) | ConvertFrom-Html

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object4.SelectSingleNode('//main') | Get-TextContent | Format-Text
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
