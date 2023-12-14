$Object1 = Invoke-WebRequest -Uri 'https://mobaxterm.mobatek.net/download-home-edition.html' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="off-canvas-wrap"]/div/div/div[2]/section[1]/div[2]/div[2]/a/text()[1]').InnerText,
  'v([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.SelectSingleNode('//*[@id="off-canvas-wrap"]/div/div/div[2]/section[1]/div[2]/div[2]/a').Attributes['href'].Value
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = "MobaXterm_installer_$($Task.CurrentState.Version).msi"
    }
  )
}

$ReleaseNotesTitleNode = $Object1.SelectSingleNode("//div[@class='tight_paragraphe' and contains(./p/text(), '$($Task.CurrentState.Version)')]")

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./p').InnerText, '\((\d{4}-\d{1,2}-\d{1,2})\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

if ($ReleaseNotesTitleNode) {
  # ReleaseNotes (zh-CN)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesTitleNode.SelectNodes('./p/following-sibling::node()') | Get-TextContent | Format-Text
  }
} else {
  $Task.Logging("No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Expand-TempArchive | Join-Path -ChildPath $Task.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Read-ProductVersionFromMsi

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
