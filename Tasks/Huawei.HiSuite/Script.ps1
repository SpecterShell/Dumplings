# Global
$Object1 = Invoke-WebRequest -Uri 'https://consumer.huawei.com/en/support/hisuite/' | ConvertFrom-Html
$Version1 = [regex]::Match(
  $Object1.SelectSingleNode('//div[@class="link-box"]/div[@class="link-item"][1]/p[@class="disc"]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# China
$Object2 = Invoke-WebRequest -Uri 'https://consumer.huawei.com/cn/support/hisuite/' | ConvertFrom-Html
$Version2 = [regex]::Match(
  $Object2.SelectSingleNode('//div[@class="tab-des-con"]/div[@class="item-con"][2]/ul/li[1]/p[@class="txt"]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

if ($Version1 -ne $Version2) {
  $this.Log("Global version: ${Version1}")
  $this.Log("China version: ${Version2}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//div[@class="link-box"]/div[@class="link-item"][1]/a').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object2.SelectSingleNode('//div[@class="tab-des-con"]/div[@class="item-con"][2]/ul/li[1]/a').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//div[@class="link-box"]/div[@class="link-item"][1]/p[@class="disc"]').InnerText,
        '(\d{4}\.\d{1,2}\.\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      if ($Global:DumplingsStorage.Contains('HiSuite') -and $Global:DumplingsStorage.HiSuite.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HiSuite[$this.CurrentState.Version].ReleaseNotes
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HiSuite[$this.CurrentState.Version].ReleaseNotesCN
        }
      } elseif ($Global:DumplingsStorage.Contains('HiSuiteCN') -and $Global:DumplingsStorage.HiSuiteCN.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HiSuiteCN[$this.CurrentState.Version].ReleaseNotes
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HiSuiteCN[$this.CurrentState.Version].ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
