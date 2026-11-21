$ProjectName = 'crystaldiskmark'
$RootPath = ''
$PatternPath = '(\d+(?:\.\d+)+[a-zA-Z]?)'
$PatternFilename = 'CrystalDiskMark\d+(?:_\d+)+[a-zA-Z]?Shizuku.*\.exe'

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${RootPath}"
$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($RootPath))/${PatternPath}/${PatternFilename}$" })

# Version
$this.CurrentState.Version = [regex]::Match($Assets[0].title.'#cdata-section', "^$([regex]::Escape($RootPath))/${PatternPath}/").Groups[1].Value

if ($Assets2 = $Object1.Where({ $_.title.'#cdata-section' -eq "${RootPath}/$($this.CurrentState.Version)/CrystalDiskMark$($this.CurrentState.Version.Replace('.', '_'))Shizuku.exe" })) {
  $Assets = $Assets2
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Assets[0].link | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Assets[0].pubDate, 'ddd, dd MMM yyyy HH:mm:ss "UT"', (Get-Culture -Name 'en-US')) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://crystalmark.info/en/software/crystaldiskmark/crystaldiskmark-history/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(@class, 'entry')]/h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notin @('h2', 'h3'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
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

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://crystalmark.info/ja/software/crystaldiskmark/crystaldiskmark-history/' | ConvertFrom-Html

      $ReleaseNotesJATitleNode = $Object3.SelectSingleNode("//div[contains(@class, 'entry')]/h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesJATitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesJATitleNode.NextSibling; $Node -and $Node.Name -notin @('h2', 'h3'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (ja-JP)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'ja-JP'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (ja-JP) for version $($this.CurrentState.Version)", 'Warning')
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
