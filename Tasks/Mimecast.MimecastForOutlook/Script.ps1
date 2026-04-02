# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture        = 'x86'
  InstallerType       = 'zip'
  NestedInstallerType = 'wix'
  InstallerUrl        = $Global:DumplingsStorage.MimecastDownloadPage.SelectSingleNode('//tr[contains(./td[1], "Mimecast for Outlook")]/td[2]//a[contains(., "32-bit")]').Attributes['href'].Value | ConvertTo-HtmlDecodedText
}
$HttpClient = [System.Net.Http.HttpClient]::new()
$HttpRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $InstallerX86.InstallerUrl)
$HttpResponse = $HttpClient.Send($HttpRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
$VersionX86 = [regex]::Match(($HttpResponse.Content.Headers.ContentDisposition.FileName | ConvertTo-UnescapedUri), '(\d+(?:\.\d+)+)').Groups[1].Value
$HttpRequest.Dispose()
$HttpResponse.Dispose()

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'wix'
  InstallerUrl        = $Global:DumplingsStorage.MimecastDownloadPage.SelectSingleNode('//tr[contains(./td[1], "Mimecast for Outlook")]/td[2]//a[contains(., "64-bit")]').Attributes['href'].Value | ConvertTo-HtmlDecodedText
}
$HttpRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $InstallerX64.InstallerUrl)
$HttpResponse = $HttpClient.Send($HttpRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
$VersionX64 = [regex]::Match(($HttpResponse.Content.Headers.ContentDisposition.FileName | ConvertTo-UnescapedUri), '(\d+(?:\.\d+)+)').Groups[1].Value
$HttpRequest.Dispose()
$HttpResponse.Dispose()

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.msi') }, 'First')[0].FullName.Replace('/', '\') })
      $ZipFile.Dispose()
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
