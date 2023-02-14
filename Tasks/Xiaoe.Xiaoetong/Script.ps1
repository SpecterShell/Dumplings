$Object1 = Invoke-RestMethod -Uri 'https://class-server.xiaoeknow.com/client/xe.big_class.client.check_version?sv=Windows&sw=0&dn=0' -Method Post

$Task.CurrentState = Invoke-RestMethod -Uri "$($Object1.data.url)/latest.yml" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix "$($Object1.data.url)/" -Locale 'zh-CN'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.remark -creplace '<p>(.+?)</p>', "`$1`n" | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
