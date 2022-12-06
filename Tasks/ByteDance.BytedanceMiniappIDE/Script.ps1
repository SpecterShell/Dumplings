$Object1 = Invoke-RestMethod -Uri 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=6898629266087352589&branch=master&buildId=&uid='

# Version
$Task.CurrentState.Version = $Object1.data.manifest.win32.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.manifest.win32.urls[0]
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.releaseNote | Format-Text | ConvertTo-UnorderedList
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # TODO: Get the latest ReleaseNotes from https://developer.open-douyin.com/docs/resource/zh-CN/mini-app/develop/developer-instrument/download/developer-instrument-update-and-download/

    # $Object2 = Invoke-RestMethod -Uri 'https://lf-cdn-tos.bytescm.com/obj/static/docs/resource/page-data/zh-CN/mini-app/develop/developer-instrument/download/developer-instrument-update-and-download/page-data.d54366d08371445a82cc246a109f9fdf.json'

    # try {
    #   $Task.CurrentState.ReleaseTime = [regex]::Match(
    #     $Object2.result.pageContext.htmlAst.children.Where({ $_.tagName -eq 'h1' -and $_.children[0].value.Contains($Task.CurrentState.Version) }).children[0].value,
    #     '(\d{4}-\d{1,2}-\d{1,2})'
    #   ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    # } catch {
    #   Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    # }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
