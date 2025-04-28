$Prefix = 'https://releases.hashicorp.com/vagrant/'
$Object1 = Invoke-WebRequest -Uri $Prefix

$FolderName = $Object1.Links.Where({ try { $_.href -match '^/vagrant/\d+(?:\.\d+)+/$' } catch {} }).href | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($FolderName, '(\d+(?:\.\d+)+)').Groups[1].Value

$Prefix = Join-Uri $Prefix $FolderName
$Object2 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('i686') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('amd64') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotes'
        Value = $ReleaseNotesUrl = 'https://github.com/hashicorp/vagrant/blob/HEAD/CHANGELOG.md'
      }

      $Object3 = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/hashicorp/vagrant/HEAD/CHANGELOG.md' | Convert-MarkdownToHtml
      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotes'
          Value = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
