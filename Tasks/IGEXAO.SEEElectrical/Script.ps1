$Object1 = Invoke-WebRequest -Uri 'https://www.ige-xao.com/en-uk/trials/see-electrical/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.outerHTML -match 'alt="Download"' } catch {} })[0].href
}

$HttpClient = [System.Net.Http.HttpClient]::new()
$HttpRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $this.CurrentState.Installer[0].InstallerUrl)
$HttpResponse = $HttpClient.Send($HttpRequest, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)

# Version
$this.CurrentState.Version = [regex]::Match(($HttpResponse.Content.Headers.ContentDisposition.FileName | ConvertTo-UnescapedUri), '(\d+(?:\.\d+)+)').Groups[1].Value

$HttpRequest.Dispose()
$HttpResponse.Dispose()

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
