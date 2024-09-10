$Object1 = Invoke-WebRequest -Uri 'https://www.gonitro.com/pro/try/trial/download/thanks'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(\.\d+){2,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.gonitro.com/product-details/release-notes' | ConvertFrom-Html

      if ($Object2.SelectSingleNode("//span[@class='versionLabel']/following-sibling::text()[string()='$($this.CurrentState.Version)']")) {
        $ReleaseNotesNode = $Object2.SelectSingleNode('//*[contains(@class, "AccordionSection-content")][1]')
        $ReleaseTimeNode = $ReleaseNotesNode.SelectSingleNode('./*[contains(.//*, "Release date")]')

        if ($ReleaseTimeNode) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseTimeNode.InnerText, '([a-zA-Z]+ \d{1,2}, \d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseTimeNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNode | Get-TextContent | Format-Text
          }
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
