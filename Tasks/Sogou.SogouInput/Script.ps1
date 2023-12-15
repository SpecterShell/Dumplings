$Content = (Invoke-WebRequest -Uri 'https://pinyin.sogou.com/windows/').Content

$Match = [regex]::Match($Content, 'window\.location\.href\s*=\s*"(.+?/pc/dl/gzindex/.+?/sogou_pinyin_(.+?)\.exe.+?)"')

# Version
$Task.CurrentState.Version = $Match.Groups[2].Value

$Object1 = $Content | ConvertFrom-Html

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($Object1.SelectSingleNode('//*[@id="banner0_text3"]').InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Match.Groups[1].Value | Read-ProductVersionFromExe

    # Installer
    $Task.CurrentState.Installer += [ordered]@{
      InstallerUrl = "https://ime.sogoucdn.com/sogou_pinyin_$($Task.CurrentState.RealVersion).exe"
    }

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
        $Task.Logging("No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
