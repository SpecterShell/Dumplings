$Object1 = Invoke-RestMethod -Uri 'https://lceda.cn/api/latestClientVersion'

# Version
$Task.CurrentState.Version = $Object1.result

$Object2 = Invoke-WebRequest -Uri 'https://lceda.cn/page/download' | ConvertFrom-Html

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl1 = $Object2.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[3]/div/span[2]/a').Attributes['href'].Value
}
if (!$InstallerUrl1.Contains($Task.CurrentState.Version)) {
  throw "Task $($Task.Name): The InstallerUrl`n${InstallerUrl1}`ndoesn't contain version $($Task.CurrentState.Version)"
}

$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl2 = $Object2.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[3]/div/span[1]/a').Attributes['href'].Value
}
if (!$InstallerUrl2.Contains($Task.CurrentState.Version)) {
  throw "Task $($Task.Name): The InstallerUrl`n${InstallerUrl2}`ndoesn't contain version $($Task.CurrentState.Version)"
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Object3 = Invoke-WebRequest -Uri 'https://lceda.cn/page/update-record' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[contains(@class, 'doc-body-left')]/p[contains(./strong/text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $ReleaseNotesTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]')
        $Task.CurrentState.ReleaseTime = [System.Web.HttpUtility]::HtmlDecode($ReleaseNotesTimeNode.InnerText).Trim() | Get-Date -Format 'yyyy-MM-dd'

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
