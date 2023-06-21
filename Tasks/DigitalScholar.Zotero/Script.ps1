$Object1 = Invoke-RestMethod -Uri 'https://www.zotero.org/download/client/update/0/0/WINNT_x86/en-US/release/update.xml'

# Version
$Task.CurrentState.Version = $Version = $Object1.updates.update.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri "https://www.zotero.org/download/client/dl?channel=release&platform=win32&version=${Version}"
}

# Sometimes the installer does not match the version
if (-not $InstallerUrl.Contains($Version)) {
  Write-Host -Object "Task $($Task.Name): The installer does not match the version" -ForegroundColor Yellow

  # Version
  $Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'Zotero-([\d\.]+)').Groups[1].Value
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Uri2 = 'https://www.zotero.org/support/changelog'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[starts-with(@id, 'changes_in_$($Version.Replace('.', ''))')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '\((.+?)\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Uri2 + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
        }
      } else {
        # ReleaseNotesUrl
        $Task.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Uri2
        }

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
