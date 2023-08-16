$Object1 = Invoke-RestMethod -Uri 'https://www.feishu.cn/api/downloads' -Headers @{
  cookie = '__tea__ug__uid=1'
}

# Version
$Task.CurrentState.Version = $Version = [regex]::Match($Object1.versions.Windows.version_number, 'V([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.versions.Windows.download_link
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.versions.Windows.release_time | ConvertFrom-UnixTimeSeconds

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Uri2 = 'https://www.feishu.cn/hc/en-US/articles/360043073734'
    $Object2 = Invoke-WebRequest -Uri $Uri2 | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable |
      Select-Object -ExpandProperty Values | Where-Object -FilterScript { $_ -is [array] -and $_.tabName }

    try {
      $ReleaseNotesNode = $Object2 | Where-Object -FilterScript { $_.html.html.Contains("V$($Version.Split('.')[0..1] -join '.')") }
      if ($ReleaseNotesNode) {
        $ReleaseNotesTitleNode = ($ReleaseNotesNode.html.html | ConvertFrom-Html).SelectSingleNode("/div/div/div[contains(.//text(), 'V$($Version.Split('.')[0..1] -join '.')')]")
        if ($ReleaseNotesTitleNode) {
          # ReleaseNotes (en-US)
          $ReleaseNotesNodes = @()
          for ($Node = $ReleaseNotesTitleNode.NextSibling; -not $Node.SelectSingleNode('.//text()[contains(., "Updated")]|.//hr') ; $Node = $Node.NextSibling) {
            $ReleaseNotesNodes += $Node
          }
          $Task.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          # ReleaseNotesUrl (en-US)
          $Task.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotesUrl'
            Value  = $ReleaseNotesTitleNode.SelectSingleNode('.//a').Attributes['href'].Value
          }
        }
      } else {
        # ReleaseNotesUrl (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $Uri2
        }

        Write-Host -Object "Task $($Task.Name): No ReleaseNotes (en-US) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    $Uri3 = 'https://www.feishu.cn/hc/zh-CN/articles/360043073734'
    $Object3 = Invoke-WebRequest -Uri $Uri3 | Read-ResponseContent | Get-EmbeddedJson -StartsFrom 'window._templateValue = ' | ConvertFrom-Json -AsHashtable |
      Select-Object -ExpandProperty Values | Where-Object -FilterScript { $_ -is [array] -and $_.tabName }

    try {
      $ReleaseNotesNode = $Object3 | Where-Object -FilterScript { $_.html.html.Contains("V$($Version.Split('.')[0..1] -join '.')") }
      if ($ReleaseNotesNode) {
        $ReleaseNotesTitleNode = ($ReleaseNotesNode.html.html | ConvertFrom-Html).SelectSingleNode("/div/div/div[contains(.//text(), 'V$($Version.Split('.')[0..1] -join '.')')]")
        if ($ReleaseNotesTitleNode) {
          # ReleaseNotes (zh-CN)
          $ReleaseNotesNodes = @()
          for ($Node = $ReleaseNotesTitleNode.NextSibling; -not $Node.SelectSingleNode('.//text()[contains(., "发布于")]|.//hr') ; $Node = $Node.NextSibling) {
            $ReleaseNotesNodes += $Node
          }
          $Task.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }

          # ReleaseNotesUrl (zh-CN)
          $Task.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotesUrl'
            Value  = $ReleaseNotesTitleNode.SelectSingleNode('.//a').Attributes['href'].Value
          }
        }
      } else {
        # ReleaseNotesUrl (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = $Uri3
        }

        Write-Host -Object "Task $($Task.Name): No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
