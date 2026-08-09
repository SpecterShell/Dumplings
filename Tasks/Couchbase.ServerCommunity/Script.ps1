$Object1 = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.couchbase.com/downloads?family=enterprise-analytics'
  Read-PlaywrightPageContent -Page $Page
} | Get-EmbeddedJson -StartsFrom 'window.downloadData = ' | ConvertFrom-Json -AsHashtable
$Object2 = $Object1.'couchbase-server-community'.GetEnumerator().Where({ $_.Key -match 'Current' }, 'First')[0].Value

# Version
$this.CurrentState.Version = [regex]::Match($Object2.version, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.downloads.Where({ $_.platforms -match 'Windows' }, 'First')[0].download_link
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://docs.couchbase.com/server/current/release-notes/relnotes.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//article/div[@class='sect1' and contains(./h2, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = @($ReleaseNotesTitleNode.SelectSingleNode('./div[@class="sectionbody"]'))
        $ReleaseNotesNodes += for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.HasClass('sect1') -and $Node.SelectSingleNode('./h2[contains(., "Release")]')); $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
