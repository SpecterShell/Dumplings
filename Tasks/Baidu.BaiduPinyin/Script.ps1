$Object1 = Invoke-RestMethod -Uri 'https://imehd.baidu.com/nodeApi/getTplDetail?token=4b5b978065af11ee8148d75d569ec4b6'

# Version
$Task.CurrentState.Version = [regex]::Match($Object1.data.content.updataLogVersion, 'V([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.content.updataLogDown
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.data.content.updataLogTime,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://shurufa.baidu.com/update' | ConvertFrom-Html

    try {
      if ($Object2.SelectSingleNode('//*[@id="update_body"]/div/div/div[1]/span[2]').InnerText.Contains($Task.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('//*[@class="update-item-split"][1]/following::*[@class="update-item-con"][count(.|//*[@class="update-item-tit"][2]/preceding::*[@class="update-item-con"])=count(//*[@class="update-item-tit"][2]/preceding::*[@class="update-item-con"])]') | Get-TextContent | Format-Text
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
