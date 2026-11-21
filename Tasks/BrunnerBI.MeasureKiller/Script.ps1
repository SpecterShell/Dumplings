$Prefix = 'https://www.measurekiller.com/downloads/'
$Object1 = Invoke-WebRequest -Uri $Prefix

$FolderName = $Object1.Links.Where({ try { $_.href -match '^\d+(?:\.\d+)+/$' } catch {} }).href | Sort-Object -Property { [ChunkVersion]($_) } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($FolderName, '(\d+(?:\.\d+)+)').Groups[1].Value

$Prefix += $FolderName
$Object2 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('Setup') -and -not $_.href.Contains('Portable') } catch {} }, 'First')[0].href
}
# $this.CurrentState.Installer += [ordered]@{
#   InstallerType = 'msi'
#   InstallerUrl  = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('Setup') } catch {} }, 'First')[0].href
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://measurekiller.com/download' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//article[contains(.//summary, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesNode.SelectSingleNode('.//summary').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove list prefix
        $ReleaseNotesNode.SelectNodes('.//*[text()="·"]').ForEach({ $_.Remove() })
        # Remove "View on GitHub"
        $ReleaseNotesNode.SelectNodes('.//a[contains(., "View on GitHub")]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectNodes('.//summary/following-sibling::node()') | Get-TextContent | Format-Text
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
