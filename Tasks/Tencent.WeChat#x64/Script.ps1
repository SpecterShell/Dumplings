function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromNSIS
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

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
      $this.Log("No ReleaseNotesUrl (zh-Hans) and ReleaseNotesUrl (zh-Hans-CN) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Query        = [ordered]@{}
  Architecture = 'x64'
  InstallerUrl = 'https://dldir1v6.qq.com/weixin/Windows/WeChatSetup.exe'
}

# Last Modified
$this.CurrentState.LastModified = (Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head).Headers.'Last-Modified'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The Last Modified is unchanged
if ([datetime]$this.CurrentState.LastModified -eq [datetime]$this.LastState.LastModified) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
} elseif ([datetime]$this.CurrentState.LastModified -lt [datetime]$this.LastState.LastModified) {
  $this.Log("The last modified datetime from the current state `"$($this.CurrentState.LastModified)`" is older than the one from the last state `"$($this.LastState.LastModified)`"", 'Warning')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 4: The Last Modified has updated, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The Last Modified has changed, but the SHA256 is not', 'Info')

  $this.Write()
  return
}

switch -Regex ($this.Check()) {
  # Case 6: The Last Modified, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The Last Modified and the SHA256 have changed, but the version is not
  default {
    $this.Log('The Last Modified and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
