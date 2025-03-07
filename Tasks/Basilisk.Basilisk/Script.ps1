# x86
$Object1 = Invoke-RestMethod -Uri 'https://aus.basilisk-browser.org/?application=basilisk&arch=WINNT_x86-msvc&channel=release&force=1'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://aus.basilisk-browser.org/?application=basilisk&arch=WINNT_x86_64-msvc&channel=release&force=1'

if ($Object1.updates.update.appVersion -ne $Object2.updates.update.appVersion) {
  $this.Log("x86 version: $($Object1.updates.update.appVersion)")
  $this.Log("x64 version: $($Object2.updates.update.appVersion)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.updates.update.appVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://dl.basilisk-browser.org/basilisk-$($Object1.updates.update.buildID).win32.installer.exe"
  ProductCode  = "Basilisk $($this.CurrentState.Version) (x86 en-US)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://dl.basilisk-browser.org/basilisk-$($Object2.updates.update.buildID).win64.installer.exe"
  ProductCode  = "Basilisk $($this.CurrentState.Version) (x64 en-US)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.basilisk-browser.org/releasenotes.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[@class='rn-header' and contains(text(), '$($Object2.updates.update.displayVersion)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::*[@class="rn-date"]')
        if ($ReleaseTimeNode) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseTimeNode.InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value

          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseTimeNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
          }
        } else {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
          }
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($Object2.updates.update.displayVersion)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
