$Object1 = Invoke-WebRequest -Uri 'https://easyeda.com/page/download' | ConvertFrom-Html

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl1 = $Object1.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[3]/div/span[2]/a').Attributes['href'].Value
}
$Version1 = [regex]::Match($InstallerUrl1, '(\d+\.\d+\.\d+)\.exe').Groups[1].Value

$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl2 = $Object1.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[3]/div/span[1]/a').Attributes['href'].Value
}
$Task.CurrentState.Version = $Version2 = [regex]::Match($InstallerUrl2, '(\d+\.\d+\.\d+)\.exe').Groups[1].Value

if ($Version1 -ne $Version2) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Task.Config.Notes = '检测到不同的版本'
} else {
  $Identical = $True
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://easyeda.com/page/update-record' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[contains(@class, 'doc-body-left')]/p[contains(./strong/text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $ReleaseNotesTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]')
        $Task.CurrentState.ReleaseTime = ($ReleaseNotesTimeNode.InnerText | ConvertTo-HtmlDecodedText).Trim() | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTimeNode.NextSibling; -not $Node.SelectSingleNode('./strong'); $Node = $Node.NextSibling) {
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
  ({ $_ -ge 3 -and $Identical }) {
    $Task.Submit()
  }
}
