# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Global:DumplingsStorage.Axes4DownloadPage.Links.Where({ try { $_.href.Contains('axesSlide') -and $_.href -match 'Setup' -and $_.OuterHTML -notmatch 'beta' } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:_\d+)+)').Groups[1].Value.Replace('_', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://support.axes4.com/hc/sections/15126768343314'
      }

      $ReleaseNotesUrl = 'https://support.axes4.com/hc/en-us/sections/15126768343314-Release-Notes'
      $Object1 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
      $ReleaseNotesUrlNode = $Object1.SelectSingleNode("//ul[contains(@class, 'article-list')]//a[contains(., '$($this.CurrentState.Version -replace '(\.0+)+$')')]")

      if ($ReleaseNotesUrlNode) {
        $ReleaseNotesUrl = Join-Uri $ReleaseNotesUrl $ReleaseNotesUrlNode.Attributes['href'].Value
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl -replace '/en-us/', '/' -replace '(?<=articles/\d+)-.+'
        }

        $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        $ReleaseNotesNode = $Object3.SelectSingleNode("//div[@class='article-body']")
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesNode.ChildNodes[0]; $Node -and -not ($Node.Name -eq 'h2' -and $Node.InnerText.Contains('Download')); $Node = $Node.NextSibling) {
          if ($Node.InnerText -match 'Release date') {
            $Node = $Node.SelectSingleNode('./following-sibling::h2/preceding-sibling::node()[1]')
          } else {
            $Node
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
