# Installer
$Object1 = Invoke-WebRequest -Uri 'https://cdn.crabnebula.app/download/heidi-scribe/scribe/latest/platform/nsis-x86_64' -Method Head
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.BaseResponse.RequestMessage.RequestUri.AbsoluteUri | ConvertTo-UnescapedUri
}
$Object2 = Invoke-WebRequest -Uri 'https://cdn.crabnebula.app/download/heidi-scribe/scribe/latest/platform/wix-x86_64' -Method Head
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $Object2.BaseResponse.RequestMessage.RequestUri.AbsoluteUri | ConvertTo-UnescapedUri
}

$VersionNSIS = [regex]::Match(
  [System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse($Object1.Headers.'Content-Disposition'[0]).FileName,
  '(\d+(?:\.\d+)+)'
).Groups[1].Value
$VersionWiX = [regex]::Match(
  [System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse($Object2.Headers.'Content-Disposition'[0]).FileName,
  '(\d+(?:\.\d+)+)'
).Groups[1].Value

if ($VersionNSIS -ne $VersionWiX) {
  $this.Log("Inconsistent versions: NSIS: ${VersionNSIS}, WiX: ${VersionWiX}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionNSIS

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
