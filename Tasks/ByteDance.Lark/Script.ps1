$Object = Invoke-RestMethod -Uri 'https://www.larksuite.com/api/downloads'

# Version
$this.CurrentState.Version = $Version = [regex]::Match($Object.versions.Windows.version_number, 'V([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.versions.Windows.download_link
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.versions.Windows.release_time | ConvertFrom-UnixTimeSeconds

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Uri2 = 'https://www.larksuite.com/hc/en-US/articles/360046836333'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable |
      Select-Object -ExpandProperty Values | Where-Object -FilterScript { $_ -is [array] -and $_.tabName }

    try {
      $ReleaseNotesNode = $Object2 | Where-Object -FilterScript { $_.html.html.Contains("V$($Version.Split('.')[0..1] -join '.')") }
      if ($ReleaseNotesNode) {
        $ReleaseNotesTitleNode = ($ReleaseNotesNode.html.html | ConvertFrom-Html).SelectSingleNode("/div/div/div[contains(.//text(), 'V$($Version.Split('.')[0..1] -join '.')')]")
        if ($ReleaseNotesTitleNode) {
          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = @()
          for ($Node = $ReleaseNotesTitleNode.NextSibling; -not $Node.SelectSingleNode('.//text()[contains(., "Updated")]|.//hr') ; $Node = $Node.NextSibling) {
            $ReleaseNotesNodes += $Node
          }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          # ReleaseNotesUrl (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotesUrl'
            Value  = $ReleaseNotesTitleNode.SelectSingleNode('.//a').Attributes['href'].Value
          }
        }
      } else {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $Uri2
        }

        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $Uri3 = 'https://www.larksuite.com/hc/zh-CN/articles/360046836333'
    $Object3 = Invoke-WebRequest -Uri $Uri3 | Read-ResponseContent | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable |
      Select-Object -ExpandProperty Values | Where-Object -FilterScript { $_ -is [array] -and $_.tabName }

    try {
      $ReleaseNotesNode = $Object3 | Where-Object -FilterScript { $_.html.html.Contains("V$($Version.Split('.')[0..1] -join '.')") }
      if ($ReleaseNotesNode) {
        $ReleaseNotesTitleNode = ($ReleaseNotesNode.html.html | ConvertFrom-Html).SelectSingleNode("/div/div/div[contains(.//text(), 'V$($Version.Split('.')[0..1] -join '.')')]")
        if ($ReleaseNotesTitleNode) {
          # ReleaseNotes (zh-CN)
          $ReleaseNotesNodes = @()
          for ($Node = $ReleaseNotesTitleNode.NextSibling; -not $Node.SelectSingleNode('.//text()[contains(., "发布于")]|.//hr') ; $Node = $Node.NextSibling) {
            $ReleaseNotesNodes += $Node
          }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          # ReleaseNotesUrl (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotesUrl'
            Value  = $ReleaseNotesTitleNode.SelectSingleNode('.//a').Attributes['href'].Value
          }
        }
      } else {
        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $Uri3
        }

        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
