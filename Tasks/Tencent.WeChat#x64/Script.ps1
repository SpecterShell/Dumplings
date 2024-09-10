function Get-ReleaseNotes {
  try {
    $Object3 = Invoke-WebRequest -Uri "https://dldir1v6.qq.com/weixin/Windows/update$($this.CurrentState.Version).xml" | Read-ResponseContent | ConvertFrom-Xml

    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $Object3.updateConfig.UpdateNotice.language.Where({ $_.code -eq 'en' }, 'First')[0].ChildNodes.'#text' | Format-Text
    }
    # ReleaseNotes (zh-Hans)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-Hans'
      Key    = 'ReleaseNotes'
      Value  = $Object3.updateConfig.UpdateNotice.language.Where({ $_.code -eq 'zh_CN' }, 'First')[0].ChildNodes.'#text' | Format-Text
    }
    # ReleaseNotes (zh-Hans-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-Hans-CN'
      Key    = 'ReleaseNotes'
      Value  = $Object3.updateConfig.UpdateNotice.language.Where({ $_.code -eq 'zh_CN' }, 'First')[0].ChildNodes.'#text' | Format-Text
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }

  try {
    # ReleaseNotesUrl (zh-Hans)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-Hans'
      Key    = 'ReleaseNotesUrl'
      Value  = $ReleaseNotesUrl = 'https://weixin.qq.com/cgi-bin/readtemplate?lang=zh_CN&t=weixin_faq_list'
    }
    # ReleaseNotesUrl (zh-Hans-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-Hans-CN'
      Key    = 'ReleaseNotesUrl'
      Value  = 'https://weixin.qq.com/cgi-bin/readtemplate?lang=zh_CN&t=weixin_faq_list'
    }

    $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    $ReleaseNotesUrlNode = $Object4.SelectSingleNode("/html/body/div/div[3]/div[1]/div[2]/section[contains(./h3/text(), 'Windows')]/ul/li[contains(./a/span[1], '$([regex]::Match($this.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]/a")
    if ($ReleaseNotesUrlNode) {
      # ReleaseNotesUrl (zh-Hans)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-Hans'
        Key    = 'ReleaseNotesUrl'
        Value  = Join-Uri 'https://weixin.qq.com' ($ReleaseNotesUrlNode.Attributes['href'].Value | ConvertTo-HtmlDecodedText).Replace('?ang', '?lang')
      }
      # ReleaseNotesUrl (zh-Hans-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-Hans-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = Join-Uri 'https://weixin.qq.com' ($ReleaseNotesUrlNode.Attributes['href'].Value | ConvertTo-HtmlDecodedText).Replace('?ang', '?lang')
      }
    } else {
      $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Uri1 = 'https://dldir1v6.qq.com/weixin/Windows/WeChatSetup.exe'
$Object1 = Invoke-WebRequest -Uri $Uri1 -Method Head
# MD5
$this.CurrentState.MD5 = $Object1.Headers.'X-COS-META-MD5'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = [regex]::Match((7z.exe l -ba -slt $InstallerFile), 'Path = \[(\d+\.\d+\.\d+\.\d+)\]').Groups[1].Value

  try {
    $Uri2 = "https://dldir1v6.qq.com/weixin/Windows/WeChat$($this.CurrentState.Version).exe"
    $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2
    }
    # MD5 alternative
    $this.CurrentState.MD5A = $Object2.Headers.'X-COS-META-MD5'[0]
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture    = 'x64'
      InstallerUrl    = $Uri1
      InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = [regex]::Match((7z.exe l -ba -slt $InstallerFile), 'Path = \[(\d+\.\d+\.\d+\.\d+)\]').Groups[1].Value

  try {
    $Uri2 = "https://dldir1v6.qq.com/weixin/Windows/WeChat$($this.CurrentState.Version).exe"
    $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2
    }
    # MD5 alternative
    $this.CurrentState.MD5A = $Object2.Headers.'X-COS-META-MD5'[0]
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture    = 'x64'
      InstallerUrl    = $Uri1
      InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

if ($this.CurrentState.MD5 -eq $this.LastState.MD5) {
  # Version
  $this.CurrentState.Version = $this.LastState.Version
  # If the alternative installer URL exists, don't fallback to the main one
  if ($this.LastState.Mode -eq $true) {
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2 = $this.LastState.Installer[0].InstallerUrl
    }
    # Mode
    $this.CurrentState.Mode = $true

    $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
    # MD5 alternative
    $this.CurrentState.MD5A = $Object2.Headers.'X-COS-META-MD5'[0]

    # Case 2: Both the main and the alternative MD5 was not updated
    if ($this.CurrentState.MD5A -eq $this.LastState.MD5A) {
      $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
      return
    }

    Get-ReleaseNotes

    # Case 3: The main MD5 wasn't updated, but the alternative one was
    $this.Log('The alternative MD5 was updated', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
  } else {
    try {
      $Uri2 = "https://dldir1v6.qq.com/weixin/Windows/WeChat$($this.CurrentState.Version).exe"
      $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
      # Installer
      $this.CurrentState.Installer += [ordered]@{
        Architecture = 'x64'
        InstallerUrl = $Uri2
      }
      # MD5 alternative
      $this.CurrentState.MD5A = $Object2.Headers.'X-COS-META-MD5'[0]
      # Mode
      $this.CurrentState.Mode = $true

      Get-ReleaseNotes

      # Case 4: Detected alternative installer URL
      $this.Log('Detected alternative installer URL', 'Info')
      $this.Print()
      $this.Write()
      return
    } catch {
      # Case 5: The main MD5 was not updated, and the alternative installer URL doesn't exist
      return
    }
  }
} else {
  $InstallerFile = Get-TempFile -Uri $Uri1
  # Version
  $this.CurrentState.Version = [regex]::Match((7z.exe l -ba -slt $InstallerFile), 'Path = \[(\d+\.\d+\.\d+\.\d+)\]').Groups[1].Value

  try {
    # The main MD5 was updated, and the alternative installer URL exists
    $Uri2 = "https://dldir1v6.qq.com/weixin/Windows/WeChat$($this.CurrentState.Version).exe"
    $Object2 = Invoke-WebRequest -Uri $Uri2 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $Uri2
    }
    # MD5 alternative
    $this.CurrentState.MD5A = $Object2.Headers.'X-COS-META-MD5'[0]
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    # The main MD5 was updated, but the alternative installer URL doesn't exist
    $this.Log("${Uri2} doesn't exist, fallback to ${Uri1}", 'Warning')
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture    = 'x64'
      InstallerUrl    = $Uri1
      InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    }
    # Mode
    $this.CurrentState.Mode = $false
  }

  Get-ReleaseNotes

  switch -Regex ($this.Check()) {
    # Case 7: The installer URL was updated
    'Changed|Updated|Rollbacked' {
      $this.Print()
      $this.Write()
      $this.Message()
    }
    # Case 8: The MD5 and the version were updated
    'Updated|Rollbacked' {
      $this.Submit()
    }
    # Case 6: The MD5 was updated, but the version wasn't
    Default {
      $this.Log('The MD5 was updated, but the version is the same', 'Info')
      $this.Config.IgnorePRCheck = $true
      $this.Print()
      $this.Write()
      $this.Message()
      $this.Submit()
    }
  }
}
