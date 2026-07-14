# x86
$Object1 = Invoke-WebRequest -Uri 'https://www.benthicsoftware.com/install/goldview.htm' | ConvertFrom-Html
$VersionX86 = $Object1.SelectSingleNode('.//meta[@http-equiv="fversion"]').Attributes['content'].Value
# x64
$Object2 = Invoke-WebRequest -Uri 'https://www.benthicsoftware.com/install/goldview-64.htm' | ConvertFrom-Html
$VersionX64 = $Object2.SelectSingleNode('.//meta[@http-equiv="fversion"]').Attributes['content'].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Global:DumplingsStorage.BenthicSoftwarePrefix $Global:DumplingsStorage.BenthicSoftwareApps.Links.Where({ $_.href.EndsWith('.exe') -and $_.href -match 'goldview4setup' -and $_.href -match '32bit' }, 'First')[0].href
  ProductCode  = "Goldview$($this.CurrentState.Version.Split('.')[0])32_is1"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Global:DumplingsStorage.BenthicSoftwarePrefix $Global:DumplingsStorage.BenthicSoftwareApps.Links.Where({ $_.href.EndsWith('.exe') -and $_.href -match 'goldview4setup' -and $_.href -match '64bit' }, 'First')[0].href
  ProductCode  = "Goldview$($this.CurrentState.Version.Split('.')[0])64_is1"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.SelectSingleNode('.//meta[@http-equiv="fdate"]').Attributes['content'].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.benthicsoftware.com/goldview.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[@id='goldview_history_tabpanel']//h2[contains(text(), 'Version $($this.CurrentState.RealVersion.Split('.')[0..1] -join '.') Build $($this.CurrentState.RealVersion.Split('.')[3])')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
