$Object1 = Invoke-WebRequest -Uri 'https://clientapi.dbvis.com/CheckForUpdate/' -Method Post -Body @{
  isAutoInstallAvailable = 'true'
  dbvisVersion           = $this.Status.Contains('New') ? '24.3.3' : $this.LastState.Version
  dbvisEdition           = 'Free'
} | ConvertFrom-Html

if (-not $Object1.SelectSingleNode('//a[@action="upgrade"]')) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$Prefix = $Object1.SelectSingleNode('//a[@action="upgrade"]').Attributes['href'].Value

$Object2 = Invoke-RestMethod -Uri $Prefix
$AssetX64 = $Object2.updateDescriptor.entry.Where({ $_.targetMediaFileId -eq '1178' }, 'First')[0]
$AssetArm64 = $Object2.updateDescriptor.entry.Where({ $_.targetMediaFileId -eq '4443' }, 'First')[0]

if ($AssetX64.newVersion -ne $AssetArm64.newVersion) {
  $this.Log("x64 version $($AssetX64.newVersion)", 'Warning')
  $this.Log("arm64 version $($AssetArm64.newVersion)", 'Warning')
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $AssetX64.newVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerUrl    = Join-Uri $Prefix $AssetX64.fileName
  InstallerSha256 = $AssetX64.sha256Sum.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  InstallerUrl    = Join-Uri $Prefix $AssetArm64.fileName
  InstallerSha256 = $AssetArm64.sha256Sum.ToUpper()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.dbvis.com/releasenotes/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove table header
        $ReleaseNotesTitleNode.SelectNodes('./following-sibling::*//div[contains(@class, "releaseNote__note--head")]').ForEach({ $_.Remove() })
        # Turn details column into div
        $ReleaseNotesTitleNode.SelectNodes('./following-sibling::*//div[contains(@class, "releaseNote__note--row")]/span[position() > 1]').ForEach({ $_.Name = 'div' })
        # Remove "gap"
        $ReleaseNotesTitleNode.SelectNodes('./following-sibling::*//div[contains(@class, "gap")]').ForEach({ $_.Remove() })

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
