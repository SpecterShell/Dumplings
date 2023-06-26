$Object1 = (Invoke-RestMethod -Uri 'https://s.pcmgr.qq.com/tapi/web/searchcgi.php?type=search&keyword=%E5%BE%AE%E4%BF%A1').list.Where({ $_.SoftID -eq 11488 })[0].xmlInfo | ConvertFrom-Xml

# Version
$Task.CurrentState.Version = $Object1.soft.versionname

try {
  $InstallerUrl = "https://dldir1.qq.com/weixin/Windows/WeChat$($Task.CurrentState.Version).exe"
  Invoke-WebRequest -Uri $InstallerUrl -Method Head | Out-Null
  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $InstallerUrl
  }
} catch {
  Write-Host -Object "Task $($Task.Name): ${InstallerUrl} doesn't exist, fallback to $($Object1.soft.https.'#cdata-section')" -ForegroundColor Yellow
  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.soft.https.'#cdata-section'
  }
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri "https://dldir1.qq.com/weixin/Windows/update$($Task.CurrentState.Version).xml" | Read-ResponseContent | ConvertFrom-Xml

    try {
      # ReleaseNotes (en-US)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.updateConfig.UpdateNotice.language.Where({ $_.code -eq 'en' })[0].ChildNodes.'#text' | Format-Text
      }
      # ReleaseNotes (zh-Hans)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'zh-Hans'
        Key    = 'ReleaseNotes'
        Value  = $Object2.updateConfig.UpdateNotice.language.Where({ $_.code -eq 'zh_CN' })[0].ChildNodes.'#text' | Format-Text
      }
      # ReleaseNotes (zh-Hans-CN)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'zh-Hans-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.updateConfig.UpdateNotice.language.Where({ $_.code -eq 'zh_CN' })[0].ChildNodes.'#text' | Format-Text
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    $Object3 = Invoke-WebRequest -Uri 'https://weixin.qq.com/cgi-bin/readtemplate?lang=zh_CN&t=weixin_faq_list' | ConvertFrom-Html

    try {
      $ReleaseNotesUrlNode = $Object3.SelectSingleNode("/html/body/div/div[3]/div[1]/div[2]/section[contains(./h3/text(), 'Windows')]/ul/li[contains(./a/span[1], '$([regex]::Match($Task.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]/a")
      if ($ReleaseNotesUrlNode) {
        # ReleaseNotesUrl (zh-Hans)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-Hans'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://weixin.qq.com' + ($ReleaseNotesUrlNode.Attributes['href'].Value | ConvertTo-HtmlDecodedText).Replace('?ang', '?lang')
        }
        # ReleaseNotesUrl (zh-Hans-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-Hans-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://weixin.qq.com' + ($ReleaseNotesUrlNode.Attributes['href'].Value | ConvertTo-HtmlDecodedText).Replace('?ang', '?lang')
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotesUrl for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
        # ReleaseNotesUrl (zh-Hans)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-Hans'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://weixin.qq.com/cgi-bin/readtemplate?lang=zh_CN&t=weixin_faq_list'
        }
        # ReleaseNotesUrl (zh-Hans-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-Hans-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://weixin.qq.com/cgi-bin/readtemplate?lang=zh_CN&t=weixin_faq_list'
        }
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
