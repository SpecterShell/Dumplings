# $Object1 = Invoke-RestMethod -Uri 'https://www.xmedia-recode.de/getCurrentVersion.php' | ConvertFrom-Ini

# # Version
# $this.CurrentState.Version = $Object1.Update.Version

# # Installer
# $this.CurrentState.Installer += [ordered]@{
#   InstallerUrl = "https://www.xmedia-recode.de/download/XMediaRecode$($Object1.Update.VersionID)_x64_setup.exe"
# }

$Object1 = Invoke-WebRequest -Uri 'https://www.xmedia-recode.de/en/download.php' | ConvertFrom-Html
# x86
# $Object2 = $Object1.SelectSingleNode('//div[@class="container"]/div[(contains(.//h2/text(), "32 bit") or contains(.//h2/text(), "32bit")) and contains(.//h2/text(), "Installer")][1]//table[@class="download_table"]/tbody')
# x64
$Object3 = $Object1.SelectSingleNode('//div[@class="container"]/div[(contains(.//h2/text(), "64 bit") or contains(.//h2/text(), "64bit")) and contains(.//h2/text(), "Installer")][1]//table[@class="download_table"]/tbody')

# $VersionX86 = $Object2.SelectSingleNode('./tr[1]/td[2]/text()').InnerText.Trim()
$VersionX64 = $Object3.SelectSingleNode('./tr[1]/td[2]/text()').InnerText.Trim()

# if ($VersionX86 -ne $VersionX64) {
#   $this.Log("x86 version: ${VersionX86}")
#   $this.Log("x64 version: ${VersionX64}")
#   throw 'Inconsistent versions detected'
# }

# Version
$this.CurrentState.Version = $VersionX64

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = $Object2.SelectSingleNode('.//a[@class="download_link"]').Attributes['href'].Value
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object3.SelectSingleNode('.//a[@class="download_link"]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object4 = Invoke-WebRequest -Uri 'https://www.xmedia-recode.de/en/version.php' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object4.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]')
        try {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
            [regex]::Match($ReleaseTimeNode.InnerText, '(\d{1,2}\.\d{1,2}\.\d{4})').Groups[1].Value,
            'dd.MM.yyyy',
            $null
          ).ToString('yyyy-MM-dd')

          $ReleaseNotesNodes = for ($Node = $ReleaseTimeNode.NextSibling; $Node -and -not ($Node.Name -eq 'a' -and $Node.InnerText.Contains('Download')); $Node = $Node.NextSibling) { $Node }
        } catch {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')

          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not ($Node.Name -eq 'a' -and $Node.InnerText.Contains('Download')); $Node = $Node.NextSibling) { $Node }
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
