# Installer
# $this.CurrentState.Installer += $InstallerX86 = [ordered]@{
#   Architecture  = 'x86'
#   InstallerType = 'nullsoft'
#   InstallerUrl  = Get-RedirectedUrl -Uri 'https://thestempedia.com/product/pictoblox/download-pictoblox/windows-32bit/primary/'
# }
# $VersionX86 = [regex]::Match($InstallerX86.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = Get-RedirectedUrl -Uri 'https://thestempedia.com/product/pictoblox/download-pictoblox/windows-64-bit/primary/'
}
$VersionX64 = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# $this.CurrentState.Installer += $InstallerMSI = [ordered]@{
#   Architecture  = 'x64'
#   InstallerType = 'wix'
#   InstallerUrl  = Get-RedirectedUrl -Uri 'https://thestempedia.com/product/pictoblox/download-pictoblox/msi/primary'
# }
# $VersionMSI = [regex]::Match($InstallerMSI.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# if (@(@($VersionX86, $VersionX64, $VersionMSI) | Sort-Object -Unique).Count -gt 1) {
#   $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}, msi: ${VersionMSI}", 'Error')
#   return
# }

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://thestempedia.com/product/pictoblox/release-notes/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(@class, 'elementor-tab-title') and contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[contains(@class, "elementor-tab-content")]').ChildNodes[0]; $Node; $Node = $Node.NextSibling) {
          if ($Node.InnerText -match '(\d{1,2}[a-zA-Z]+\W+[a-zA-Z]+\W+20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
              $Matches[1],
              [string[]]@(
                "d'st' MMMM, yyyy"
                "d'nd' MMMM, yyyy"
                "d'rd' MMMM, yyyy"
                "d'th' MMMM, yyyy"
              ),
              (Get-Culture -Name 'en-US'),
              [System.Globalization.DateTimeStyles]::None
            ).ToString('yyyy-MM-dd')
          } elseif ($Node.InnerText -match '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } else {
            $Node
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
