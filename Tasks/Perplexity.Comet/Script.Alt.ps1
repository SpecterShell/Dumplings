# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl1st -Uri 'https://www.perplexity.ai/rest/browser/download?platform=win_x64&channel=stable' -Method GET -Headers @{ 'x-perplexity-comet-download-token' = 'miniinstaller' }
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = Get-RedirectedUrl1st -Uri 'https://www.perplexity.ai/rest/browser/download?platform=win_arm64&channel=stable' -Method GET -Headers @{ 'x-perplexity-comet-download-token' = 'miniinstaller' }
# }
# $VersionARM64 = [regex]::Match($this.CurrentState.Installer[1].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# if ($VersionX64 -ne $VersionARM64) {
#   $this.Log("Inconsistent versions: x64: $VersionX64, arm64: $VersionARM64", 'Error')
#   return
# }

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
