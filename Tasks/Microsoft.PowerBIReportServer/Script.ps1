$Object1 = Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/power-platform/products/power-bi/report-server'
$Object2 = Invoke-WebRequest -Uri $Object1.Links.Where({ try { $_.outerHTML.Contains('Advanced download options') } catch {} }, 'First')[0].href | Get-EmbeddedJson -StartsFrom 'window.__DLCDetails__=' | ConvertFrom-Json
$Object3 = $Object2.dlcDetailsView.downloadFile.Where({ $_.name -eq 'PowerBIReportServer.exe' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object3.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object3.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.datePublished | Get-Date | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MicrosoftDocs/powerbi-docs/refs/heads/main/powerbi-docs/report-server/changelog.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//li/em[contains(., 'build $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
