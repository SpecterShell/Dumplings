$Object1 = Invoke-RestMethod -Uri 'https://typora.io/releases/windows_64.json'

# Version
$Task.CurrentState.Version = $Object1.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.download.Replace('update', 'setup')
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Object1.downloadCN.Replace('update', 'setup')
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://typora.io/releases/stable' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='write']/h2[contains(text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = @()
        switch ($ReleaseNotesTitleNode.SelectNodes('./following-sibling::*')) {
          ({ $_.Name -eq 'h2' }) { break }
          ({ $_.InnerText.Contains('See detail') }) {
            $ReleaseNotesUrl = $_.SelectSingleNode('./a').Attributes['href'].Value
            continue
          }
          ({ $_.Name -eq 'a' }) { continue }
          Default {
            $ReleaseNotesNodes += $_
            continue
          }
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

    # ReleaseNotesUrl
    $Task.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = $ReleaseNotesUrl ?? 'https://typora.io/releases/stable'
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
}
