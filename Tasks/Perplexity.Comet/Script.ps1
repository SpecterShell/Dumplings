# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://www.perplexity.ai/rest/browser/download?platform=win_x64&channel=stable'
}
$VersionX64 = [regex]::Match((Get-RedirectedUrl1st -Uri $InstallerX64.InstallerUrl -Method GET), '(\d+(?:\.\d+)+)').Groups[1].Value

# $this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = 'https://www.perplexity.ai/rest/browser/download?platform=win_arm64&channel=stable'
# }
# $VersionARM64 = [regex]::Match((Get-RedirectedUrl1st $InstallerARM64.InstallerUrl -Method GET), '(\d+(?:\.\d+)+)').Groups[1].Value

# if ($VersionX64 -ne $VersionARM64) {
#   $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionARM64}", 'Error')
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
