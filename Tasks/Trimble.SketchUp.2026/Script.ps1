$Object1 = Invoke-WebRequest -Uri 'https://www.sketchup.com/en/download/all'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.Links.Where({ try { $_.href.EndsWith('exe') -and $_.href.Contains('2026') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:-\d+)+)').Groups[1].Value.Replace('-', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    # try {
    #   # ReleaseNotesUrl
    #   $this.CurrentState.Locale += [ordered]@{
    #     Key   = 'ReleaseNotesUrl'
    #     Value = 'https://help.sketchup.com/release-notes'
    #   }

    #   $ReleaseNotesUrl = $Object1.Links.Where({ try { $_.href.Contains('release-notes') -and $_.href.Contains('2026') } catch {} }, 'First')[0].href
    #   $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl -UserAgent $DumplingsBrowserUserAgent
    #   if ($Object2.Content.Contains("$($this.CurrentState.RealVersion) Win 64-bit")) {
    #     $Object3 = $Object2 | ConvertFrom-Html
    #     $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//p[contains(text(), '$($this.CurrentState.RealVersion) Win 64-bit')]")

    #     # ReleaseTime
    #     $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    #     # ReleaseNotes (en-US)
    #     $this.CurrentState.Locale += [ordered]@{
    #       Locale = 'en-US'
    #       Key    = 'ReleaseNotes'
    #       Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
    #     }

    #     # ReleaseNotesUrl
    #     $this.CurrentState.Locale += [ordered]@{
    #       Key   = 'ReleaseNotesUrl'
    #       Value = $ReleaseNotesUrl.Replace('/en/', '/')
    #     }
    #   } else {
    #     $PossibleReleaseNotesUrls = $Object2.Links.Where({ try { $_.href.Contains('release-notes') -and $_.href.Contains('2026') } catch {} })
    #     $ReleaseNotesFound = $false
    #     foreach ($PossibleReleaseNotesUrl in $PossibleReleaseNotesUrls) {
    #       $PossibleReleaseNotesUrl = Join-Uri $ReleaseNotesUrl $PossibleReleaseNotesUrl.href
    #       $Object2 = Invoke-WebRequest -Uri $PossibleReleaseNotesUrl -UserAgent $DumplingsBrowserUserAgent
    #       if ($Object2.Content.Contains("$($this.CurrentState.RealVersion) Win 64-bit")) {
    #         $Object3 = $Object2 | ConvertFrom-Html
    #         $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//p[contains(text(), '$($this.CurrentState.RealVersion) Win 64-bit')]")

    #         # ReleaseTime
    #         $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    #         # ReleaseNotes (en-US)
    #         $this.CurrentState.Locale += [ordered]@{
    #           Locale = 'en-US'
    #           Key    = 'ReleaseNotes'
    #           Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
    #         }

    #         # ReleaseNotesUrl
    #         $this.CurrentState.Locale += [ordered]@{
    #           Key   = 'ReleaseNotesUrl'
    #           Value = $PossibleReleaseNotesUrl.Replace('/en/', '/')
    #         }

    #         $ReleaseNotesFound = $true
    #         break
    #       }
    #     }
    #     if (-not $ReleaseNotesFound) {
    #       $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    #     }
    #   }
    # } catch {
    #   $_ | Out-Host
    #   $this.Log($_, 'Warning')
    # }

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
