$InstallerUrl = Get-RedirectedUrl -Uri 'https://www.trikker.be/en/web-version-windows'

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType        = 'zip'
  NestedInstallerType  = 'msi'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "Trikker_V$($this.CurrentState.Version).msi" })
  InstallerUrl         = $InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://www.trikker.be/blog/news-2'
      }

      $Object2 = Invoke-RestMethod -Uri 'https://www.trikker.be/en/blog/news-2/feed'
      $Object3 = $Object2.Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object3) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object3[0].updated | Get-Date -AsUTC

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = $Object3[0].link.href.Replace('/en/', '/')
        }

        $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object4.SelectSingleNode('//div[contains(@class, "o_wblog_post_content_field")]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
