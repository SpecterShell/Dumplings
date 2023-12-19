$Uri1 = 'https://dldir1v6.qq.com/weixin/Windows/WeChatSetup_x86.exe'

$Object1 = Invoke-WebRequest -Uri $Uri1 -Method Head -Headers @{'If-Modified-Since' = $this.LastState.LastModified } -SkipHttpErrorCheck
if ($Object1.StatusCode -eq 304) {
  $this.Logging("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}
$this.CurrentState.LastModified = $Object1.Headers.'Last-Modified'[0]

$Path = Get-TempFile -Uri $Uri1

# Version
$this.CurrentState.Version = [regex]::Match((7z l -ba -slt $Path), 'Path = \[(\d+\.\d+\.\d+\.\d+)\]').Groups[1].Value

try {
  $Uri2 = "https://dldir1v6.qq.com/weixin/Windows/WeChat$($this.CurrentState.Version).exe"
  Invoke-WebRequest -Uri $Uri2 -Method Head | Out-Null
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Uri2
  }
} catch {
  $this.Logging("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Uri1
  }
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri "https://dldir1v6.qq.com/weixin/Windows/update$($this.CurrentState.Version).xml" | Read-ResponseContent | ConvertFrom-Xml

    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.updateConfig.UpdateNotice.language.Where({ $_.code -eq 'en' })[0].ChildNodes.'#text' | Format-Text
      }
      # ReleaseNotes (zh-Hans)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-Hans'
        Key    = 'ReleaseNotes'
        Value  = $Object2.updateConfig.UpdateNotice.language.Where({ $_.code -eq 'zh_CN' })[0].ChildNodes.'#text' | Format-Text
      }
      # ReleaseNotes (zh-Hans-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-Hans-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.updateConfig.UpdateNotice.language.Where({ $_.code -eq 'zh_CN' })[0].ChildNodes.'#text' | Format-Text
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $Object3 = Invoke-WebRequest -Uri 'https://weixin.qq.com/cgi-bin/readtemplate?lang=zh_CN&t=weixin_faq_list' | ConvertFrom-Html

    try {
      $ReleaseNotesUrlNode = $Object3.SelectSingleNode("/html/body/div/div[3]/div[1]/div[2]/section[contains(./h3/text(), 'Windows')]/ul/li[contains(./a/span[1], '$([regex]::Match($this.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]/a")
      if ($ReleaseNotesUrlNode) {
        # ReleaseNotesUrl (zh-Hans)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-Hans'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://weixin.qq.com' + ($ReleaseNotesUrlNode.Attributes['href'].Value | ConvertTo-HtmlDecodedText).Replace('?ang', '?lang')
        }
        # ReleaseNotesUrl (zh-Hans-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-Hans-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://weixin.qq.com' + ($ReleaseNotesUrlNode.Attributes['href'].Value | ConvertTo-HtmlDecodedText).Replace('?ang', '?lang')
        }
      } else {
        $this.Logging("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl (zh-Hans)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-Hans'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://weixin.qq.com/cgi-bin/readtemplate?lang=zh_CN&t=weixin_faq_list'
        }
        # ReleaseNotesUrl (zh-Hans-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-Hans-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://weixin.qq.com/cgi-bin/readtemplate?lang=zh_CN&t=weixin_faq_list'
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
