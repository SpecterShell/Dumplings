$Prefix = 'https://logtalk.org/'

$Object = Invoke-WebRequest -Uri "${Prefix}download.html" | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//div[@class="article__content"]/p[1]/text()[1]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object.SelectSingleNode('//h3[@id="windows"]/following-sibling::blockquote[1]/p/a[1]').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.SelectSingleNode('//div[@class="article__content"]/p[1]/text()[3]').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/LogtalkDotOrg/logtalk3/master/RELEASE_NOTES.md' | ConvertFrom-Markdown).Html | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h1[contains(text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h1'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
