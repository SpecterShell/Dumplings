$Content = (Invoke-WebRequest -Uri 'https://pinyin.sogou.com/windows/').Content

if ($Content -cmatch 'window\.location\.href\s*=\s*".+?(/dl/gzindex/.+?/sogou_pinyin_([a-zA-Z0-9]+)\.exe).+?"') {
  # Version
  $Task.CurrentState.Version = $Matches[2]

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = "https://ime.sogoucdn.com$($Matches[1])"
  }
}

$Object1 = $Content | ConvertFrom-Html

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($Object1.SelectSingleNode('//*[@id="banner0_text3"]').InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://pinyin.sogou.com/changelog.php' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@class='changebox']/h2[contains(text(), '$($Task.CurrentState.Version.Insert(2, '.'))')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-FileVersionFromExe

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
