$DownloadPage = 'https://bowerbird.gallery/download/'
$Object1 = Invoke-WebRequest -Uri $DownloadPage

# Installer
$Link = $Object1.Links.Where({ try { $_.href.Contains('-windows.exe') -and $_.href.Contains('Bowerbird-') } catch {} }, 'First')[0]
if (-not $Link) {
  throw 'The download page does not link a Windows installer.'
}
$InstallerUrl = Join-Uri $DownloadPage $Link.href
if ($InstallerUrl -notlike 'https://downloads.bowerbird.gallery/*') {
  throw "The download page links $($InstallerUrl) instead of the official download host."
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $InstallerUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '/Bowerbird-(.+)-windows\.exe$').Groups[1].Value
if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The installer filename does not provide a numeric version.'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://bowerbird.gallery/releases/' | ConvertFrom-Html

      # The listing is newest first, and each entry is an h2 holding the bare version. Start with the
      # page URL so a failed lookup cannot leave the previous version's anchor in place.
      $ReleaseNotesUrl = 'https://bowerbird.gallery/releases/'
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      $ReleaseNotesTitleNode = $Object2.SelectNodes('//h2').Where({ $_.InnerText.Trim() -eq $this.CurrentState.Version }, 'First')[0]
      if (-not $ReleaseNotesTitleNode) {
        throw "The release notes page has no section for version $($this.CurrentState.Version)."
      }

      $ReleaseNotesAnchor = (([string]$ReleaseNotesTitleNode.id) -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
      if ($ReleaseNotesAnchor) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = "$ReleaseNotesUrl#$ReleaseNotesAnchor"
        }
      }

      $ReleaseNotesNodes = [System.Collections.Generic.List[object]]::new()
      $AvailabilityNode = $null
      for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notmatch '^h[12]$'; $Node = $Node.NextSibling) {
        # The first paragraph names the platform dates instead of describing the release.
        if (-not $AvailabilityNode -and $Node.Name -eq 'p') { $AvailabilityNode = $Node; continue }
        $ReleaseNotesNodes.Add($Node)
      }

      # ReleaseTime: the paragraph gives the Mac date first and the Windows date last.
      $ReleaseDates = [regex]::Matches([string]$AvailabilityNode.InnerText, '(\d{1,2} [A-Za-z]+ 20\d{2})')
      if ($ReleaseDates.Count) {
        $this.CurrentState.ReleaseTime = [DateTime]::ParseExact($ReleaseDates[$ReleaseDates.Count - 1].Groups[1].Value, 'd MMMM yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotes (en-US)
      $ReleaseNotes = $ReleaseNotesNodes | Get-TextContent | Format-Text
      if ([string]::IsNullOrWhiteSpace($ReleaseNotes)) {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes
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
