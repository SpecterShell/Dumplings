$Object1 = Invoke-RestMethod -Uri 'https://updates.owncloud.com/client/?version=2.10.1.7187&platform=win32&buildArch=x86_64&msi=true'

# Version
$this.CurrentState.Version = $Object1.owncloudclient.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.owncloudclient.downloadurl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # ReleaseNotesUrl
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = $ReleaseNotesUrl = 'https://owncloud.com/changelog/desktop/'
    }

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[contains(@class, 'changelog')]/div/h1[contains(./a/text(), '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '\((\d{4}-\d{1,2}-\d{1,2})\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]').NextSibling; $Node -and $Node.Name -ne 'h1'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\s\-]+', '' -creplace '\s+', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
