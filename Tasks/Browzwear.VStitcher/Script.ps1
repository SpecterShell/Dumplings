$Document = Invoke-WebRequest -Uri 'https://help.browzwear.com/en/articles/13065045-download-links' | ConvertFrom-Html
$VersionHeading = $Document.SelectNodes('//*[contains(@class,"article_body")]//h3').Where({ $_.InnerText -match 'Version \d+(?:\.\d+)+' }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($VersionHeading.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = ($this.CurrentState.Version -split '\.')[0..1] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $VersionHeading.SelectSingleNode('./following::a[contains(@href, ".exe") and contains(@href, "VStitcher") and not(contains(@href, "TechPack"))]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($VersionHeading.InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $ReleaseNotesUrl = $VersionHeading.SelectSingleNode('./following::a[contains(@href, "release-notes") and contains(@href, "vstitcher")]').Attributes['href'].Value
      if ($ReleaseNotesUrl) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl.Replace('/en/', '/')
        }

        $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
        $ReleaseNotesNodes = for ($Node = $Object2.SelectSingleNode('//article').ChildNodes[0]; $Node -and -not ($Node.Name -eq 'section' -and $Node.InnerText -match 'Related Articles'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
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
