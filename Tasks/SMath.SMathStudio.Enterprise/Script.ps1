$Object1 = Invoke-RestMethod -Uri 'https://smath.com/licensing/api/extensions?extensions=SMathStudio_Desktop&params=1111&editionId=ce6fd0a7-d407-473d-811c-1d9995e83fce&type=software&beta=False'

# Version
$this.CurrentState.Version = $Object1.extensions.items.item.version

# RealVersion
$VersionParts = $this.CurrentState.Version.Split('.')
$this.CurrentState.RealVersion = "$($VersionParts[0..([System.Math]::Min($VersionParts.Length - 1, 2))] -join '.')$($VersionParts.Count -ge 4 ? "-$($VersionParts[3..($VersionParts.Count - 1)])" : '')"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.extensions.items.item.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://smath.com/en-US/view/SMathStudioEnterprise/history' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='ver_$($this.CurrentState.Version -replace '[_.]', '_')']")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotesUrl (en-US)
        # Unlike other packages, only the ReleaseNotesUrl in the en-US locale manfiest will be changed as the ReleaseNotes is empty in other locales
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://smath.com/view/SMathStudioEnterprise/history' + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
        }

        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact($ReleaseNotesTitleNode.SelectSingleNode('.//*[@itemprop="datePublished"]').InnerText, 'M/d/yyyy', $null).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.Attributes.Contains('id'); $Node = $Node.NextSibling) { $Node }
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
