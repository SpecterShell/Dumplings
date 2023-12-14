$Object = Invoke-RestMethod -Uri 'https://ai.10jqka.com.cn/java-extended-api/voyageversion/getDefaultVersionInfo'

# Version
$Task.CurrentState.Version = $Object.data.version

# Installer
$InstallerUrl = Get-RedirectedUrl1st -Uri 'https://download.10jqka.com.cn/index/download/id/275/'
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

if (!$InstallerUrl.Contains($Task.CurrentState.Version)) {
  throw "Task $($Task.Name): The InstallerUrl`n${InstallerUrl}`ndoesn't contain version $($Task.CurrentState.Version)"
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.description | Format-Text
}

# ReleaseNotesUrl
$Task.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object.data.introductionLink
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
