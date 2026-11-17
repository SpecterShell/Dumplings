$Object1 = Invoke-WebRequest -Uri 'https://sval.app/download/' | Read-ResponseContent | ConvertFrom-Html

# Installer
$InstallerHref = ($Object1.SelectNodes('//a[contains(@href, "sval-")][contains(@href, "-windows-x86_64-setup.exe")]') | Select-Object -First 1).GetAttributeValue('href', '')

# Version
$this.CurrentState.Version = [regex]::Match($InstallerHref, '/releases/([^/]+)/').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://download.sval.app/releases/$($this.CurrentState.Version)/sval-$($this.CurrentState.Version)-windows-x86_64-setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Article = $Object1.SelectSingleNode('//section[@id="release-notes"]//article[.//div[contains(@class,"note-version") and normalize-space(text())="' + $this.CurrentState.Version + '"]]')
      if ($Article) {
        # ReleaseTime
        $NoteDate = $Article.SelectSingleNode('.//div[contains(@class,"note-date")]').InnerText.Trim()
        $this.CurrentState.ReleaseTime = [DateTime]::Parse($NoteDate, [System.Globalization.CultureInfo]::GetCultureInfo('en-US'))

        # ReleaseNotes (en-US): the What's-new items are badge spans followed by text spans.
        $Groups = [ordered]@{
          New      = [System.Collections.Generic.List[string]]::new()
          Fixed    = [System.Collections.Generic.List[string]]::new()
          Security = [System.Collections.Generic.List[string]]::new()
        }
        $CurrentGroup = $null
        foreach ($Span in $Article.SelectSingleNode('.//div[contains(@class,"changes")]').SelectNodes('./span')) {
          $Class = $Span.GetAttributeValue('class', '')
          if ($Class -match '(^|\s)badge\s+new(\s|$)') { $CurrentGroup = 'New'; continue }
          if ($Class -match '(^|\s)badge\s+fixed(\s|$)') { $CurrentGroup = 'Fixed'; continue }
          if ($Class -match '(^|\s)badge\s+security(\s|$)') { $CurrentGroup = 'Security'; continue }
          $Text = $Span.InnerText.Trim()
          if ($CurrentGroup -and $Text) { $Groups[$CurrentGroup].Add($Text) }
        }
        $Lines = [System.Collections.Generic.List[string]]::new()
        foreach ($GroupName in 'New', 'Fixed', 'Security') {
          if ($Groups[$GroupName].Count -gt 0) {
            $Lines.Add($GroupName)
            foreach ($Item in $Groups[$GroupName]) { $Lines.Add("- $Item") }
            $Lines.Add('')
          }
        }
        while ($Lines.Count -gt 0 -and -not $Lines[$Lines.Count - 1]) { $Lines.RemoveAt($Lines.Count - 1) }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($Lines -join "`n") | Format-Text
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
