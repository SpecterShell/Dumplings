$Prefix = 'https://download.blender.org/release/'

$Object1 = Invoke-WebRequest -Uri $Prefix

$Prefix += $Object1.Links | Where-Object -FilterScript { try { $_.href -match 'Blender\d+(?:\.\d+)+/' } catch {} } | Select-Object -ExpandProperty 'href' | Sort-Object -Property { [version][regex]::Match($_, '(\d+(?:\.\d+)+)').Groups[1].Value } -Bottom 1

$Object2 = Invoke-WebRequest -Uri $Prefix

$InstallerNameX64 = $Object2.Links | Where-Object -FilterScript { try { $_.href.EndsWith('.msi') -and $_.href.Contains('x64') } catch {} } | Select-Object -ExpandProperty 'href' | Sort-Object -Property { [version][regex]::Match($_, '(\d+(?:\.\d+)+)').Groups[1].Value } -Bottom 1
$VersionX64 = [regex]::Match($InstallerNameX64, '(\d+(?:\.\d+)+)').Groups[1].Value

$InstallerNameARM64 = $Object2.Links | Where-Object -FilterScript { try { $_.href.EndsWith('.msi') -and $_.href.Contains('arm64') } catch {} } | Select-Object -ExpandProperty 'href' | Sort-Object -Property { [version][regex]::Match($_, '(\d+(?:\.\d+)+)').Groups[1].Value } -Bottom 1
$VersionARM64 = [regex]::Match($InstallerNameARM64, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionARM64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $InstallerNameX64
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Prefix $InstallerNameARM64
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # try {
    #   # ReleaseNotesUrl
    #   $this.CurrentState.Locale += [ordered]@{
    #     Key   = 'ReleaseNotesUrl'
    #     Value = "https://www.blender.org/download/releases/$($this.CurrentState.Version.Split('.')[0..1] -join '-')/"
    #   }
    # } catch {
    #   $_ | Out-Host
    #   $this.Log($_, 'Warning')
    # }

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
