$Object1 = (Invoke-RestMethod -Uri 'https://fastcopy.jp/fastcopy-update2.dat').Split(':')

# Version
$this.CurrentState.Version = $Object1[$Object1.IndexOf('ver') + 2]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://$($Object1[$Object1.IndexOf('sites') + 3])$($Object1[$Object1.IndexOf('path') + 2])"
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1[$Object1.IndexOf('time') + 2], 'yyyyMMddHHmmss', $null) | ConvertTo-UtcDatetime -Id 'Tokyo Standard Time'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://fastcopy.jp/help/fastcopy_eng.htm' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//h2[@id='history']/following-sibling::div[@class='help_section'][1]/table/tr[./td[1]/text()='v$($this.CurrentState.Version)'][1]/td[2]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://fastcopy.jp/help/fastcopy_cn.htm' | ConvertFrom-Html

      $ReleaseNotesNode = $Object3.SelectSingleNode("//h2[@id='history']/following-sibling::div[@class='help_section'][1]/table/tr[./td[1]/text()='v$($this.CurrentState.Version)'][1]/td[2]")
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

    try {
      $Object4 = Invoke-WebRequest -Uri 'https://fastcopy.jp/help/fastcopy.htm' | ConvertFrom-Html

      $ReleaseNotesNode = $Object4.SelectSingleNode("//h2[@id='history']/following-sibling::div[@class='help_section'][1]/table/tr[./td[1]/text()='v$($this.CurrentState.Version)'][1]/td[2]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (ja-JP)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'ja-JP'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (ja-JP) for version $($this.CurrentState.Version)", 'Warning')
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
