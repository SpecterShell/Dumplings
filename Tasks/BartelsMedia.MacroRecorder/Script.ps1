$Object1 = Invoke-RestMethod -Uri 'https://www.macrorecorder.com/update3.php?os=win'

# Version
$this.CurrentState.Version = $Object1.xml.winclient.versions.minorupdate

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.macrorecorder.com/MacroRecorderSetup.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.macrorecorder.com/download/changelog/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//tr[contains(./td[2]/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          [regex]::Match($ReleaseNotesNode.SelectSingleNode('./td[1]').InnerText, '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
          'MM/dd/yyyy',
          $null
        ).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./td[3]') | Get-TextContent | Format-Text
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
