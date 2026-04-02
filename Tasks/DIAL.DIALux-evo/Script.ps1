$Prefix = 'https://www.dialux.com/en-GB/download'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, '(?s)Version.+?(\d+(?:\.\d+){2,})').Groups[1].Value

$Object2 = Invoke-WebRequest -Uri "${Prefix}/dialux-evo"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact([regex]::Match($Object1.Content, '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value, 'dd/MM/yyyy', $null).ToString('yyyy-MM-dd')

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.outerHTML.Contains('What`s new') } catch {} }, 'First')[0].href
      }

      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      if ($ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[@id='page-content']/*[contains(., 'Version: $($this.CurrentState.Version)')]")) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.InnerText -notmatch 'Version: \d+(?:\.\d+)+'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
      # ReleaseNotes (en-US)
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
