$Object1 = [Newtonsoft.Json.Linq.JObject]::Parse(
  (Invoke-WebRequest -Uri 'https://www.snowflake.com/content/snowflake-site/global/en/developers/downloads/snowsql.model.json').Content
).SelectTokens('$..downloadItems[?(@.fileName.text =~ /\.msi$/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.fileName.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://docs.snowflake.com/en/release-notes/client-change-log-snowsql' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//tr[contains(., 'SnowSQL $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::tr[1]/td[3]') | Get-TextContent | Format-Text
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
