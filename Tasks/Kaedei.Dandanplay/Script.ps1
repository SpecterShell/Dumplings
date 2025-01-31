$Object1 = Invoke-WebRequest -Uri 'https://www.dandanplay.com/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('//div[@class="memo" and contains(., "版本")]').InnerText, '(\d+(?:\.\d+){2,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.SelectSingleNode('//a[contains(@href, ".zip")]').Attributes['href'].Value -replace '\.zip$', '.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//div[@class="memo" and contains(text(), "发布日期")]').InnerText,
        '(\d{4}年\d{1,2}月\d{1,2}日)'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.dandanplay.com/blog.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@id='blogs']/ul/li[contains(./div/h4/text(), 'Windows版') and contains(./div/h4/text(), '$($this.CurrentState.Version)')]/div/p")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode | Get-TextContent | Format-Text
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
