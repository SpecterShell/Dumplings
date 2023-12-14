$Object1 = Invoke-WebRequest -Uri 'https://qiyukf.com/download' | ConvertFrom-Html

$Node = $Object1.SelectSingleNode('//div[@class="m-kefu"][1]')

# Version
$Task.CurrentState.Version = [regex]::Match($Node.SelectSingleNode('./div[@class="mid"]/p').InnerText, 'v([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Node.SelectSingleNode('./div[@class="bottom"]/a').Attributes['href'].Value.Trim()
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Node.SelectSingleNode('./div[@class="mid"]/p').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Prefix = 'http://res.qiyukf.net/qiyu-desktop/prod/'
    $Object2 = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | Read-ResponseContent | ConvertFrom-Yaml

    try {
      if ($Object2.version -eq $Task.CurrentState.Version) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.releaseNotes | Format-Text
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
