# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl1st -Uri 'https://download.10jqka.com.cn/index/download/id/84/'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'insoft_([\d\.]+)').Groups[1].Value

if (!$InstallerUrl.Contains($this.CurrentState.Version)) {
  throw "Task $($this.Name): The InstallerUrl`n${InstallerUrl}`ndoesn't contain version $($this.CurrentState.Version)"
}

$Content = (Invoke-WebRequest -Uri 'https://activity.10jqka.com.cn/acmake/cache/486.html').Content

$ReleaseNotes = @()
if ($Content -cmatch "text1:\s*'([^']+)'") {
  $ReleaseNotes += $Matches[1]
}
if ($Content -cmatch "text2:\s*'([^']+)'") {
  $ReleaseNotes += $Matches[1]
}
if ($Content -cmatch "text3:\s*'([^']+)'") {
  $ReleaseNotes += $Matches[1]
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotes | Format-Text
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
