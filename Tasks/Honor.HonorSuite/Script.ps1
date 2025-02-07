$Object1 = Invoke-WebRequest -Uri 'https://www.hihonor.com/cn/tech/honor-suite/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/p[1]/span[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/div[1]/a[1]').Attributes['href'].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "Software\HonorSuite_$($this.CurrentState.Version).exe"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//*[@class="section1"]/div[1]/div[2]/p[1]/span[1]').InnerText,
        '(\d{4}\.\d{1,2}\.\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      if ($Global:DumplingsStorage.Contains('HonorSuite') -and $Global:DumplingsStorage.HonorSuite.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HonorSuite[$this.CurrentState.Version].ReleaseNotes
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HonorSuite[$this.CurrentState.Version].ReleaseNotesCN
        }
      } elseif ($Global:DumplingsStorage.Contains('HonorSuiteCN') -and $Global:DumplingsStorage.HonorSuiteCN.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HonorSuiteCN[$this.CurrentState.Version].ReleaseNotes
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HonorSuiteCN[$this.CurrentState.Version].ReleaseNotesCN
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
