$Object1 = Invoke-WebRequest -Uri 'https://www.amyxun.com/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="corpTitle"]/h1/span[1]/div').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.SelectSingleNode('//*[@id="m346i0"]').Attributes['href'].Value | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = 'AxMath_Setup_Win.exe'
    }
  )
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="corpTitle"]/h1/span[1]/div').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://www.amyxun.com/nd.jsp?id=10' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@class='jz_fix_ue_img']/p[.//text()='AxMath V$($Task.CurrentState.Version)']")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; -not $Node.SelectSingleNode('.//text()[contains(., "----")]'); $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
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
