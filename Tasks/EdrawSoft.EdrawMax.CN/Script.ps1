$Task.CurrentState = $Temp.WondershareUpgradeInfo['5374']

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://cc-download.edrawsoft.cn/cbs_down/edraw-max_cn_$($Task.CurrentState.version)_full5374.exe"
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Object2 = (Invoke-RestMethod -Uri 'https://pixsoapi.edrawsoft.cn/api/helpcenter/draw/tutorial/list?class_id=6&product=2&platform=2').data[0].content | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h1[contains(text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::h6[1]/span').InnerText | Get-Date -Format 'yyyy-MM-dd'
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseTime for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
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
