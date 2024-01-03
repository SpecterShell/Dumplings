$Object1 = Invoke-WebRequest -Uri 'https://qiyukf.com/download' | ConvertFrom-Html

$Node = $Object1.SelectSingleNode('//div[@class="m-kefu"][1]')

# Version
$this.CurrentState.Version = $Version = [regex]::Match($Node.SelectSingleNode('./div[@class="mid"]/p').InnerText, 'v([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Node.SelectSingleNode('./div[@class="bottom"]/a').Attributes['href'].Value.Trim()
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match(
  $Node.SelectSingleNode('./div[@class="mid"]/p').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

if ($LocalStorage.Contains('QIYU') -and $LocalStorage['QIYU'].Contains($Version)) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage['QIYU'].$Version.ReleaseNotesCN
  }
} else {
  $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
