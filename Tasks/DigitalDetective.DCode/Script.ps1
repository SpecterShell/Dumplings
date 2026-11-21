$Object1 = Invoke-WebRequest -Uri 'https://www.digital-detective.net/dcode/'

# The in-app manual update check fetches https://www.digital-detective.net/scripts/DCode.txt
# (captured in VM via Fiddler). That feed advertises 5.6.24123.1 (2024-05-02) and still
# points to the same downcode URL that now serves 5.7.26188.46, so the feed is stale and
# must not be used as the version source. The download page is authoritative.

$InstallerUrl = $Object1.Links.Where({ try { $_.href -match 'download\.php\?downcode=' -and $_.OuterHTML -match 'Download DCode™' } catch {} }, 'First')[0].href

$Object2 = Invoke-WebRequest -Uri $InstallerUrl -Method Head

# Version
$this.CurrentState.Version = [regex]::Match(
  [System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse($Object2.Headers.'Content-Disposition'[0]).FileName,
  '(\d+(?:\.\d+)+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType       = 'zip'
  NestedInstallerType = 'inno'
  InstallerUrl        = $InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.Name.EndsWith('.exe') }, 'First')[0].FullName.Replace('/', '\') })
    $ZipFile.Dispose()

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
