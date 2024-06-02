$Object1 = Invoke-WebRequest -Uri 'https://kdenlive.org/en/download/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.Links | Where-Object -FilterScript { (Get-Member -Name 'href' -InputObject $_ -ErrorAction SilentlyContinue) -and $_.href.EndsWith('.exe') -and -not $_.href.Contains('standalone') } | Select-Object -First 1 | Select-Object -ExpandProperty 'href'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'kdenlive-([\d\.]+(?:-\d+)?).*?\.exe').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = $Object2.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2[0].link
        }
      } else {
        $this.Log("No dedicated release notes page for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://docs.kdenlive.org/more_information/whats_new.html'
        }
        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://docs.kdenlive.org/zh_CN/more_information/whats_new.html'
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://docs.kdenlive.org/more_information/whats_new.html'
      }
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://docs.kdenlive.org/zh_CN/more_information/whats_new.html'
      }
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://docs.kdenlive.org/en/more_information/whats_new.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object3.SelectSingleNode("//div[@class='versionadded' and contains(./p, '$($this.CurrentState.Version -replace '(\.0)+$')')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('./p[1]/following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
