$Object1 = Invoke-RestMethod -Uri 'https://www.catsxp.com/api/service/Update?cup2key=:' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request>
  <app appid="{485AC8F6-31A4-3283-B765-92E31A816C51}" version="" ap="x86-release" />
  <app appid="{485AC8F6-31A4-3283-B765-92E31A816C51}" version="" ap="x64-release" />
</request>
'@

# Version
$Task.CurrentState.Version = $Object1.response.app[1].updatecheck.manifest.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.response.app[0].updatecheck.urls.url.codebase | Select-String -Pattern 'catsxp.oss-cn-hongkong.aliyuncs.com' -Raw -SimpleMatch
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.response.app[1].updatecheck.urls.url.codebase | Select-String -Pattern 'catsxp.oss-cn-hongkong.aliyuncs.com' -Raw -SimpleMatch
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://www.catsxp.com/history' | ConvertFrom-Html
    $Object3 = Invoke-WebRequest -Uri 'https://www.catsxp.com/zh-hans/history' | ConvertFrom-Html

    try {
      $ReleaseNotesNode1 = $Object2.SelectSingleNode("//*[@id='accordion']/div[contains(./a/h4/text()[2], '$([regex]::Match($Task.CurrentState.Version, '\d+\.(\d+\.\d+\.\d+)').Groups[1].Value)')]")

      if ($ReleaseNotesNode1) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode1.SelectSingleNode('./a/h4/i').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2} \d{2}:\d{2}:\d{2})'
        ).Groups[1].Value | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode1.SelectSingleNode('./div/div') | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseTime and ReleaseNotes (en-US) for version $($Task.CurrentState.Version)", 'Warning')
      }

      $ReleaseNotesNode2 = $Object3.SelectSingleNode("//*[@id='accordion']/div[contains(./a/h4/text()[2], '$([regex]::Match($Task.CurrentState.Version, '\d+\.(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode2) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode2.SelectSingleNode('./div/div') | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes (zh-CN) for version $($Task.CurrentState.Version)", 'Warning')
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
