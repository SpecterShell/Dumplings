$Object1 = Invoke-RestMethod -Uri 'https://www.ideamaker.info/admin/ideamaker.php?hash=0&64bit=1' -UserAgent $DumplingsBrowserUserAgent

# Version
$this.CurrentState.Version = "$($Object1.ideamaker.application.major).$($Object1.ideamaker.application.minor).$($Object1.ideamaker.application.revision).$($Object1.ideamaker.application.build)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://downcdn.raise3d.com/ideamaker/release/$($Object1.ideamaker.application.major).$($Object1.ideamaker.application.minor).$($Object1.ideamaker.application.revision)/install_ideaMaker_$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = New-TempFile
    curl -fsSLA $DumplingsInternetExplorerUserAgent -o $InstallerFile $this.CurrentState.Installer[0].InstallerUrl | Out-Host

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      $ReleaseNotesObject = $Object1.ideamaker.application.releasenote.eng.'#cdata-section' | ConvertFrom-Html
      if ($ReleaseNotesUrlObject = $ReleaseNotesObject.SelectSingleNode("//a[contains(@href, 'https://www.raise3d.com/news/')]")) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = $ReleaseNotesUrlObject.Attributes['href'].Value
        }

        # Remove the link from the release notes
        $ReleaseNotesUrlObject.Remove()

        try {
          $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('//p[contains(@class, "label-date")]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
        } catch {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) and ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }

      try {
        $ReleaseNotesCNUrl = "https://www.raise3d.cn/news/ideamaker-$($Object1.ideamaker.application.major)-$($Object1.ideamaker.application.minor)-$($Object1.ideamaker.application.revision)-release-note/"
        $null = Invoke-WebRequest -Uri $ReleaseNotesCNUrl
        # ReleaseNotesUrl (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesCNUrl
        }
      } catch {
        $this.Log("No ReleaseNotesUrl (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
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
