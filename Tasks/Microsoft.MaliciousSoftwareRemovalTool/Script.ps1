# x86
$Object1 = (Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=16').Content | Get-EmbeddedJson -StartsFrom 'window.__DLCDetails__=' | ConvertFrom-Json
$Object2 = $Object1.dlcDetailsView.downloadFile | Where-Object -FilterScript { $_.name.EndsWith('.exe') } | Sort-Object -Property { [regex]::Match($_.name, 'V(\d+(?:\.\d+)+)').Groups[1].Value -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1
# x64
$Object3 = (Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=9905').Content | Get-EmbeddedJson -StartsFrom 'window.__DLCDetails__=' | ConvertFrom-Json
$Object4 = $Object3.dlcDetailsView.downloadFile | Where-Object -FilterScript { $_.name.EndsWith('.exe') } | Sort-Object -Property { [regex]::Match($_.name, 'V(\d+(?:\.\d+)+)').Groups[1].Value -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.url
}
$VersionX86 = [regex]::Match($Object2.name, '(\d+(?:\.\d+)+)').Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object4.url
}
$VersionX64 = [regex]::Match($Object4.name, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: $($VersionX86), x64: $($VersionX64)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object4.datePublished | Get-Date | ConvertTo-UtcDateTime -Id 'UTC'
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
