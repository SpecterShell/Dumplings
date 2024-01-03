$Object1 = Invoke-RestMethod -Uri 'https://ai.10jqka.com.cn/java-extended-api/voyageversion/getDefaultVersionInfo'

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl1st -Uri 'https://download.10jqka.com.cn/index/download/id/275/'
}

if (!$InstallerUrl.Contains($this.CurrentState.Version)) {
  throw "Task $($this.Name): The InstallerUrl`n${InstallerUrl}`ndoesn't contain version $($this.CurrentState.Version)"
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.description | Format-Text
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.data.introductionLink
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
