$Object = Invoke-RestMethod -Uri 'https://mkvtoolnix.download/releases.xml'

# Version
$Task.CurrentState.Version = $Object.'mkvtoolnix-releases'.release[0].version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://mkvtoolnix.download/windows/releases/$($Task.CurrentState.Version)/mkvtoolnix-32-bit-$($Task.CurrentState.Version)-setup.exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://mkvtoolnix.download/windows/releases/$($Task.CurrentState.Version)/mkvtoolnix-64-bit-$($Task.CurrentState.Version)-setup.exe"
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.'mkvtoolnix-releases'.release[0].date | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.'mkvtoolnix-releases'.release[0].changes.change | ForEach-Object -Begin {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    $ReleaseNotesList = [ordered]@{}
  } -Process {
    $ReleaseNotesList[$_.type] = $ReleaseNotesList[$_.type] + @(($_.'#text' | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent)
  } -End {
    $ReleaseNotesList.GetEnumerator().ForEach({ "$($_.Name)`n$($_.Value | ConvertTo-UnorderedList)" }) -join "`n`n" | Format-Text
  }
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
