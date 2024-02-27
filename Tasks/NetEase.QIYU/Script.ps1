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

if ($Global:LocalStorage.Contains('QIYU') -and $Global:LocalStorage['QIYU'].Contains($Version)) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $Global:LocalStorage['QIYU'].$Version.ReleaseNotesCN
  }
} else {
  $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
