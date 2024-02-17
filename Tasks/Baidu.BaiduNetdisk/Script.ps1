$Object1 = Invoke-RestMethod -Uri 'https://pan.baidu.com/disk/cmsdata?platform=guanjia'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.list[0].version, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = [regex]::Match($Object1.list[0].version, '(\d+\.\d+\.\d+)\.\d+').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.list[0].url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.list[0].publish | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.list[0].detail.more | Format-Text | ConvertTo-OrderedList
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
