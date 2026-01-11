# x64
$Object1 = (Invoke-WebRequest -Uri 'https://updates.emeditor.com/emed64_updates5u.txt' | Read-ResponseContent | ConvertFrom-Ini).GetEnumerator().Where({ $_.Name.StartsWith('update64') }, 'First')[0].Value

# Version
$this.CurrentState.Version = $Object1.Version

# RealVersion
$this.CurrentState.RealVersion = $Object1.ProductVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.URL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.ReleaseDate, 'dd/MM/yyyy', $null).Tostring('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = 'https://www.emeditor.com/blog/'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      if ($ReleaseNotesNode = $Object2.SelectSingleNode("//div[contains(@class, 'entry-content-wrapper') and contains(.//header[contains(@class, 'entry-content-header')], '$($this.CurrentState.RealVersion)')]")) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//div[contains(@class, "entry-content")]') | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = Join-Uri $ReleaseNotesUrl $ReleaseNotesNode.SelectSingleNode('.//header[contains(@class, "entry-content-header")]//a').Attributes['href'].Value
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrlCN = 'https://zh-cn.emeditor.com/blog/'
      }

      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrlCN | ConvertFrom-Html

      if ($ReleaseNotesCNNode = $Object3.SelectSingleNode("//div[contains(@class, 'entry-content-wrapper') and contains(.//header[contains(@class, 'entry-content-header')], '$($this.CurrentState.RealVersion)')]")) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNode.SelectSingleNode("//div[contains(@class, 'entry-content-wrapper') and contains(.//header[contains(@class, 'entry-content-header')], '$($this.CurrentState.RealVersion)')]//div[contains(@class, 'entry-content')]") | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = Join-Uri $ReleaseNotesUrlCN $ReleaseNotesCNNode.SelectSingleNode('.//header[contains(@class, "entry-content-header")]//a').Attributes['href'].Value
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) and ReleaseNotesUrl (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
