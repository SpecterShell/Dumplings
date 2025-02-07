$Object1 = Invoke-RestMethod -Uri 'https://download.cyberghostvpn.com/windows/webinstaller/8/version.json'

# Version
$this.CurrentState.Version = $Object1.live.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.cyberghostvpn.com/windows/webinstaller/8/WebInstaller.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://download.cyberghostvpn.com/windows/cg8-changelog/index.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@class='container' and contains(./h2/text(), '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesNode.InnerHtml, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./ul') | Get-TextContent | Format-Text
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
