# The hash part of the URL is the SHA256 hash of the machine GUID from HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography\MachineGuid
# Use a random hash here
$Hash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes([guid]::NewGuid().Guid))).ToLower()
# x64 user
$Object1 = Invoke-RestMethod -Uri "https://api2.cursor.sh/updates/api/update/win32-x64-user/cursor/$($this.LastState.Contains('Version') ? $this.LastState.Version : '0.46.10')/${Hash}/stable" -StatusCodeVariable 'StatusCodeX64'
if ($StatusCodeX64 -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# arm64 user
$Object2 = Invoke-RestMethod -Uri "https://api2.cursor.sh/updates/api/update/win32-arm64-user/cursor/$($this.LastState.Contains('Version') ? $this.LastState.Version : '0.46.10')/${Hash}/stable" -StatusCodeVariable 'StatusCodeARM64'
if ($StatusCodeARM64 -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

if ($Object1.productVersion -ne $Object2.productVersion) {
  $this.Log("x64 user version: $($Object1.productVersion)")
  $this.Log("arm64 user version: $($Object2.productVersion)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.productVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object1.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'user'
  InstallerUrl = $Object2.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = 'https://changelog.cursor.com/'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleObject = $Object2.SelectSingleNode(".//main/article[starts-with(@id, '$($this.CurrentState.Version -replace '\.0$' -replace '\.')')]")
      if ($ReleaseNotesTitleObject) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleObject.SelectNodes('.//h2[1]/following-sibling::node()') | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#' + $ReleaseNotesTitleObject.Attributes['id'].Value
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
      }
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
