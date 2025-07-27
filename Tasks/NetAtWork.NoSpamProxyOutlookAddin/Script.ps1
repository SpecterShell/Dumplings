$HttpClient = [System.Net.Http.HttpClient]::new()

# EXE
$HttpRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, 'https://service.nospamproxy.de/file/OutlookAddinSetup')
$HttpResponse = $HttpClient.Send($HttpRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
$VersionEXE = [regex]::Match($HttpResponse.Content.Headers.ContentDisposition.FileName, '(\d+(?:\.\d+)+)').Groups[1].Value
$HttpRequest.Dispose()
$HttpResponse.Dispose()

# MSI
$HttpRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, 'https://service.nospamproxy.de/file/OutlookAddinSetupMSI')
$HttpResponse = $HttpClient.Send($HttpRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
$VersionMSI = [regex]::Match($HttpResponse.Content.Headers.ContentDisposition.FileName, '(\d+(?:\.\d+)+)').Groups[1].Value
$HttpRequest.Dispose()
$HttpResponse.Dispose()

if ($VersionEXE -ne $VersionMSI) {
  $this.Log("Inconsistent versions: EXE: ${VersionEXE}, MSI: ${VersionMSI}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionEXE
$ShortVersion = $this.CurrentState.Version.Split('.')[0..1] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = "https://service.nospamproxy.de/file/OutlookAddinSetup/${ShortVersion}"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType       = 'zip'
  NestedInstallerType = 'wix'
  InstallerUrl        = "https://service.nospamproxy.de/file/OutlookAddinSetupMSI/${ShortVersion}"
}

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
