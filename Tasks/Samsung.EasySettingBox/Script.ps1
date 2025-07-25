$Object1 = Invoke-RestMethod -Uri 'https://www.samsung.com/ie/support/model/LS27CG552EUXEN/' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//*[@data-sdf-prop="contents"]').InnerHtml | ConvertFrom-Json
# x86
$Object3 = $Object2.softwares.Where({ $_.description.Contains('Easy setting box') -and $_.description.Contains('32bit') -and $_.fileName.EndsWith('.msi') }, 'First')[0]
$VersionX86 = [regex]::Match($Object3.fileVersion, '(\d+(?:\.\d+)+)').Groups[1].Value
# x64
$Object4 = $Object2.softwares.Where({ $_.description.Contains('Easy setting box') -and $_.description.Contains('64bit') -and $_.fileName.EndsWith('.msi') }, 'First')[0]
$VersionX64 = [regex]::Match($Object4.fileVersion, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri 'https://downloadcenter.samsung.com/content/' $Object3.filePath
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://downloadcenter.samsung.com/content/' $Object4.filePath
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.fileModifiedDateCalendar | ConvertFrom-UnixTimeMilliseconds
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
