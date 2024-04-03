$Object1 = Invoke-RestMethod -Uri 'https://msedge.api.cdp.microsoft.com/api/v2/contents/Browser/namespaces/Default/names?action=batchupdates' -Method Post -Body (
  @(
    @{ 'Product' = 'msedgewebview-stable-win-x86'; 'targetingAttributes' = @{} }
    @{ 'Product' = 'msedgewebview-stable-win-x64'; 'targetingAttributes' = @{} }
    @{ 'Product' = 'msedgewebview-stable-win-arm64'; 'targetingAttributes' = @{} }
  ) | ConvertTo-Json -Compress -AsArray
) -ContentType 'application/json'

$Identical = $true
if (@($Object1.ContentId.Version | Sort-Object -Unique).Count -gt 1) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Object1[2].ContentId.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2099617'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2124701'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2099616'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  ({ $_ -match 'Updated' -and $Identical }) {
    if (Compare-Object -ReferenceObject $this.LastState -DifferenceObject $this.CurrentState -Property { $_.Installer.InstallerUrl } -IncludeEqual -ExcludeDifferent) {
      throw 'Not all installers have been updated'
    } else {
      $this.Submit()
    }
  }
}
