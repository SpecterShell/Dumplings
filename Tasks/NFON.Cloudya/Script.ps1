$Object1 = Invoke-WebRequest -Uri 'https://www.nfon.com/en/service/downloads/'

$InstallerUrl = $Object1.Links.Where({ try { $_.href.Contains('cloudya-') -and $_.href.EndsWith('.zip') -and $_.href.Contains('msi') -and $_.href.Contains('win') -and -not $_.href.Contains('crm') } catch {} }, 'First')[0].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType        = 'zip'
  NestedInstallerType  = 'msi'
  InstallerUrl         = $InstallerUrl
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "cloudya-$($this.CurrentState.Version).msi"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.nfon.com/en/service/release-notes/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//p[contains(., 'Cloudya Desktop App') and contains(./following-sibling::ul[1], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./preceding::h2[1]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ul[1]').NextSibling; $Node -and -not $Node.SelectSingleNode('./b'); $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
