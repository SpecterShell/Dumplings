$Object1 = Invoke-WebRequest -Uri 'https://lceda.cn/page/download' | ConvertFrom-Html

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = $Object1.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[2]/div/span/a').Attributes['href'].Value
}
$Task.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl.Replace('x64', 'ia32')
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://pro.lceda.cn/page/update-record' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[contains(@class, 'doc-body-left')]/p[contains(./strong/text(), '${Version}')]")
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
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
