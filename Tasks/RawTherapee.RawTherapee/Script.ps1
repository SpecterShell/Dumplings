$Object1 = Invoke-WebRequest -Uri 'https://www.rawtherapee.com/downloads/'

$Link = $Object1.Links.Where({ try { $_.outerHTML -match 'RawTherapee v(\d+(?:\.\d+)+)' } catch {} }, 'First')[0].href

# Version
$this.CurrentState.Version = $Matches[1]

$Object2 = Invoke-WebRequest -Uri $Link

# Installer
$this.CurrentState.Installer += [ordered]@{
  Query        = @{ Architecture = 'x64' }
  InstallerUrl = $Object2.Links.Where({ try { $_.outerHTML.Contains('Windows') -and $_.outerHTML.Contains('64-bit') } catch {} }, 'First')[0].href
}

# TODO: Implement manifest field removal
# if ($this.CurrentState.Installer[0].InstallerUrl.EndsWith('.exe')) {
#   $this.CurrentState.Installer[0].InstallerType = 'inno'
#   $this.CurrentState.Installer[0].NestedInstallerType = $null
#   $this.CurrentState.Installer[0].NestedInstallerFiles = $null
# } elseif ($this.CurrentState.Installer[0].InstallerUrl.EndsWith('.zip')) {
#   $this.CurrentState.Installer[0].InstallerType = 'zip'
#   $this.CurrentState.Installer[0].NestedInstallerType = 'inno'
#   $this.CurrentState.Installer[0].NestedInstallerFiles = @(
#     [ordered]@{
#       RelativeFilePath = "$($this.CurrentState.Installer[0].InstallerUrl | Split-Path -LeafBase).exe"
#     }
#   )
# } else {
#   throw "Unknown installer type: $($this.CurrentState.Installer[0].InstallerUrl)"
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Link
      }

      if ($Object2.Content -match 'released on\s+([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }

      $Object3 = $Object2 | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h2[@id='new-features']")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Name -eq 'h2' -and $Node.InnerText -match 'SHA-256|News Relevant to|Reporting Bugs'); $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Link + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
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
