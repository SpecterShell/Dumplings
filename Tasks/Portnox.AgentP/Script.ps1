$HttpClient = [System.Net.Http.HttpClient]::new()

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://clear.portnox.com/enduser/DownloadAgentPForOsAndPackageType?osType=2&packageType=Windows_x86&architecture=X64'
}
$HttpRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $InstallerX86.InstallerUrl)
$HttpResponse = $HttpClient.Send($HttpRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
$VersionX86 = [regex]::Match($HttpResponse.Content.Headers.ContentDisposition.FileName, '(\d+(?:\.\d+)+)').Groups[1].Value
$HttpRequest.Dispose()
$HttpResponse.Dispose()

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://clear.portnox.com/enduser/DownloadAgentPForOsAndPackageType?osType=2&packageType=Windows_x64&architecture=X64'
}
$HttpRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $InstallerX64.InstallerUrl)
$HttpResponse = $HttpClient.Send($HttpRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
$VersionX64 = [regex]::Match($HttpResponse.Content.Headers.ContentDisposition.FileName, '(\d+(?:\.\d+)+)').Groups[1].Value
$HttpRequest.Dispose()
$HttpResponse.Dispose()

# $this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = 'https://clear.portnox.com/enduser/DownloadAgentPForOsAndPackageType?osType=2&packageType=Windows_x64&architecture=Arm64'
# }
# $HttpRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $InstallerARM64.InstallerUrl)
# $HttpResponse = $HttpClient.Send($HttpRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
# $VersionARM64 = [regex]::Match($HttpResponse.Content.Headers.ContentDisposition.FileName, '(\d+(?:\.\d+)+)').Groups[1].Value
# $HttpRequest.Dispose()
# $HttpResponse.Dispose()

# if ($VersionX64 -ne $VersionARM64) {
#   $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionARM64}", 'Error')
#   return
# }

if (@(@($VersionX86, $VersionX64) | Sort-Object -Unique).Count -gt 1) {
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
