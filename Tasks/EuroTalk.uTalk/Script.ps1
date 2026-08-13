# $Object1 = Invoke-RestMethod -Uri 'https://s3.eu-west-1.amazonaws.com/live.cdn.utalk.com/Application/pc/updates.txt'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $InstallerUrlX86 = 'https://utalk.com/download?os_version=windows32'
}
$ResponseX86 = Invoke-WebRequest -Uri $InstallerUrlX86 -Method Head
$VersionX86 = [regex]::Match([System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse($ResponseX86.Headers.'Content-Disposition'[0]).FileName, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $InstallerUrlX64 = 'https://utalk.com/download?os_version=windows64'
}
$ResponseX64 = Invoke-WebRequest -Uri $InstallerUrlX64 -Method Head
$VersionX64 = [regex]::Match([System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse($ResponseX64.Headers.'Content-Disposition'[0]).FileName, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
