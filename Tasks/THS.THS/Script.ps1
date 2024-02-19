# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl1st -Uri 'https://download.10jqka.com.cn/index/download/id/84/'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'insoft_([\d\.]+)').Groups[1].Value

if (!$InstallerUrl.Contains($this.CurrentState.Version)) {
  throw "Task $($this.Name): The InstallerUrl`n${InstallerUrl}`ndoesn't contain version $($this.CurrentState.Version)"
}

$Object1 = (Invoke-WebRequest -Uri 'https://activity.10jqka.com.cn/acmake/cache/486.html').Content

$ReleaseNotes = @()
if ($Object1 -cmatch "text1:\s*'([^']+)'") {
  $ReleaseNotes += $Matches[1]
}
if ($Object1 -cmatch "text2:\s*'([^']+)'") {
  $ReleaseNotes += $Matches[1]
}
if ($Object1 -cmatch "text3:\s*'([^']+)'") {
  $ReleaseNotes += $Matches[1]
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotes | Format-Text
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
