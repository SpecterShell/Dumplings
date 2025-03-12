$Object1 = Invoke-RestMethod -Uri 'https://appapi.cc.163.com/v1/mixteamversion/getVersionList'

# Version
$this.CurrentState.Version = $Object1.data.versionList[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.versionList[0].downloadUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.versionList[0].downLoadUrlFor64
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.versionList[0].updateTs | ConvertFrom-UnixTimeMilliseconds

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = ($Object1.data.versionList[0].content | ConvertFrom-Html | Get-TextContent | Format-Text) -creplace '^\d{4}-\d{1,2}-\d{1,2}\n', '' | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    # RealVersion
    # The version can only be obtained from the ARP registry after installation
    # The installer is not totally silent (a messagebox will popup when the software is running)
    # Use ThreadJob with a timeout to avoid being stuck, and the script will fail in the next expression
    Start-ThreadJob -ScriptBlock { Start-Process -FilePath $using:InstallerFile -ArgumentList '/S' -Wait } | Wait-Job -Timeout 300 | Receive-Job | Out-Host
    $this.CurrentState.RealVersion = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\NetEaseDD' -Name 'DisplayVersion'

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
