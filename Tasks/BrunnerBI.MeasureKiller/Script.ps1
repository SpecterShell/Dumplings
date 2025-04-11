$Prefix = 'https://www.measurekiller.com/downloads/'
$Object1 = Invoke-WebRequest -Uri $Prefix

$FolderName = $Object1.Links.Where({ try { $_.href -match '^\d+(?:\.\d+)+/$' } catch {} }).href | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($FolderName, '(\d+(?:\.\d+)+)').Groups[1].Value

$Prefix += $FolderName
$Object2 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('Setup') -and -not $_.href.Contains('Portable') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('Setup') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://en.brunner.bi/measurekiller' | ConvertFrom-Html
      $ReleaseTimeNode = $Object2.SelectSingleNode("//p[contains(./span, 'Release Notes') and ./following-sibling::p[contains(./span, 'Version $($this.CurrentState.Version)')]]")
      if ($ReleaseTimeNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseTimeNode.InnerText, '(\d{1,2}\W+\d{1,2}\W+20\d{2})').Groups[1].Value,
          'MM/dd/yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        $ReleaseNotesTitleNode = $ReleaseTimeNode.SelectSingleNode("./following-sibling::p[contains(./span, 'Version $($this.CurrentState.Version)')]")
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.InnerText.StartsWith('Version '); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
