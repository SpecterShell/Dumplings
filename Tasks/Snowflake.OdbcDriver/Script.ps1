$Object1 = Invoke-WebRequest -Uri 'https://www.snowflake.com/content/snowflake-site/global/en/developers/downloads/odbc.model.json'
# x86
$Object2 = [Newtonsoft.Json.Linq.JObject]::Parse($Object1.Content).SelectTokens('$..downloadItems[?(@.fileName.text =~ /snowflake32.+\.msi$/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json
# x64
$Object3 = [Newtonsoft.Json.Linq.JObject]::Parse($Object1.Content).SelectTokens('$..downloadItems[?(@.fileName.text =~ /snowflake64.+\.msi$/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json

if ($Object2.version -ne $Object3.version) {
  $this.Log("x86 version: $($Object2.version)")
  $this.Log("x64 version: $($Object3.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object3.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.fileName.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object3.fileName.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.releaseDate | Get-Date | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $ReleaseNotesUrl = "https://docs.snowflake.com/en/release-notes/clients-drivers/odbc-$((Get-Date).Year).html"
      $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl
      }

      # Remove anchors
      $Object4.SelectNodes('.//a[@class="headerlink"]').ForEach({ $_.Remove() })

      $ReleaseNotesTitleNode = $Object4.SelectSingleNode("//h2[contains(., 'Version $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
