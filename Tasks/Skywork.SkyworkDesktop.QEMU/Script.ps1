$Object1 = Invoke-RestMethod -Uri 'https://desktop-llm.skywork.ai/skycowork_llm/v1/version'

# Version
$this.CurrentState.Version = $Object1.data.latest_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://static-us-img.skywork.ai/skycode/changelog/index.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//article[contains(./div[@class='release-meta'], '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesNode.SelectSingleNode('.//div[@class="release-date"]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove "Latest" label
        $ReleaseNotesNode.SelectNodes('.//*[contains(@class, "badge-latest")]').ForEach({ $_.Remove() })
        # Wrap labels
        $ReleaseNotesNode.SelectNodes('.//span[contains(@class, "tag")]').ForEach({ $_.InnerHtml = "[$($_.InnerHtml)] " })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('.//div[@class="card"]') | Get-TextContent | Format-Text
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
