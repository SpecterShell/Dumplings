$Object1 = Invoke-RestMethod -Uri 'https://sourceforge.net/projects/qbittorrent/rss?path=/qbittorrent-win32'

# Version
$this.CurrentState.Version = [regex]::Match(
  ($Object1.title.'#cdata-section' -match 'setup\.exe$')[0],
  '/qbittorrent-([\d\.]+)/'
).Groups[1].Value

$Assets = $Object1.Where({ $_.title.'#cdata-section'.Contains($this.CurrentState.Version) -and $_.title.'#cdata-section'.EndsWith('setup.exe') })

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Global:InstallerUrl = $Assets.Where({ $_.title.'#cdata-section'.Contains('x64') -and -not $_.title.'#cdata-section'.Contains('lt20') }, 'First')[0].link | ConvertTo-UnescapedUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact(
  $Assets.Where({ $_.title.'#cdata-section'.Contains('x64') -and -not $_.title.'#cdata-section'.Contains('lt20') }, 'First')[0].pubDate,
  'ddd, dd MMM yyyy HH:mm:ss "UT"',
  (Get-Culture -Name 'en-US')
) | ConvertTo-UtcDateTime -Id 'UTC'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/qbittorrent/qBittorrent-website/master/src/news.md' | ConvertFrom-Markdown).Html | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h3[contains(.//text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # Remove the header of the library version table
        $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::details/table/thead')?.Remove()

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
