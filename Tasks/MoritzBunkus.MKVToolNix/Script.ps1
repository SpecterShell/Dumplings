$Object = Invoke-RestMethod -Uri 'https://mkvtoolnix.download/releases.xml'

# Version
$this.CurrentState.Version = $Object.'mkvtoolnix-releases'.release[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://mkvtoolnix.download/windows/releases/$($this.CurrentState.Version)/mkvtoolnix-32-bit-$($this.CurrentState.Version)-setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://mkvtoolnix.download/windows/releases/$($this.CurrentState.Version)/mkvtoolnix-64-bit-$($this.CurrentState.Version)-setup.exe"
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.'mkvtoolnix-releases'.release[0].date | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
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
