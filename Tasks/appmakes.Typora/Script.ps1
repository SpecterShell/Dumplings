# x86
$Object1 = Invoke-RestMethod -Uri 'https://typora.io/releases/windows_32.json'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://typora.io/releases/windows_64.json'
# arm64
$Object3 = Invoke-RestMethod -Uri 'https://typora.io/releases/windows_arm.json'

# Version
$this.CurrentState.Version = @($Object1, $Object2, $Object3) | Select-Object -ExpandProperty version |
  Sort-Object -Property { $_ -creplace '\d+', { $_.Value.PadLeft(20) } } | Select-Object -Last 1

# Installer
if ($this.CurrentState.Version -eq $Object1.version) {
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $Object1.download.Replace('update', 'setup')
  }
  $this.CurrentState.Installer += [ordered]@{
    InstallerLocale = 'zh-CN'
    Architecture    = 'x86'
    InstallerUrl    = $Object1.downloadCN.Replace('update', 'setup')
  }
}
if ($this.CurrentState.Version -eq $Object2.version) {
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $Object2.download.Replace('update', 'setup')
  }
  $this.CurrentState.Installer += [ordered]@{
    InstallerLocale = 'zh-CN'
    Architecture    = 'x64'
    InstallerUrl    = $Object2.downloadCN.Replace('update', 'setup')
  }
}
if ($this.CurrentState.Version -eq $Object3.version) {
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'arm64'
    InstallerUrl = $Object3.download.Replace('update', 'setup')
  }
  $this.CurrentState.Installer += [ordered]@{
    InstallerLocale = 'zh-CN'
    Architecture    = 'arm64'
    InstallerUrl    = $Object3.downloadCN.Replace('update', 'setup')
  }
}

$Identical = $true
if (-not $this.LastState.Installer.Architecture -or (Compare-Object -ReferenceObject $this.LastState.Installer.Architecture -DifferenceObject $this.CurrentState.Installer.Architecture)) {
  $this.Logging('Distinct architecture detected', 'Warning')
  $Identical = $false
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object4 = Invoke-WebRequest -Uri 'https://typora.io/releases/stable' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object4.SelectSingleNode("//*[@id='write']/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = @()
        switch ($ReleaseNotesTitleNode.SelectNodes('./following-sibling::*')) {
          ({ $_.Name -eq 'h2' }) { break }
          ({ $_.InnerText.Contains('See detail') }) {
            $ReleaseNotesUrl = $_.SelectSingleNode('./a').Attributes['href'].Value
            continue
          }
          ({ $_.Name -eq 'a' }) { continue }
          Default {
            $ReleaseNotesNodes += $_
            continue
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    # ReleaseNotesUrl
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = $ReleaseNotesUrl ?? 'https://typora.io/releases/stable'
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
