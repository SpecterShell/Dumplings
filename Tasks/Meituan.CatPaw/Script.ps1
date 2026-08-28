# x64 user
$Object1 = Invoke-RestMethod -Uri 'https://catpaw.meituan.com/api/ide/update/api/update/win32-x64-user/stable/latest' -Headers @{
  'ide-version' = $this.Status.Contains('New') ? '2025.9.5' : $this.LastState.Version
  'ide-type'    = 'CatPaw'
  'tenant'      = '5282fa6645'
} -StatusCodeVariable 'StatusCode'

if ($StatusCode -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.productVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.url
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
