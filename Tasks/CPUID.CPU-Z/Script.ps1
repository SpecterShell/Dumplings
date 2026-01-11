$Object1 = (Invoke-RestMethod -Uri 'https://download.cpuid.com/cpuid.ver') -replace ';(\r\n|\n)', '$1' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.CPUID_VER.cpuz

# RealVersion
$VersionParts = $this.CurrentState.Version.Split('.')
$this.CurrentState.RealVersion = "$($VersionParts[0]).$($VersionParts[1])$($VersionParts[2])"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  InstallerUrl    = "https://download.cpuid.com/cpu-z/cpu-z_$($this.CurrentState.RealVersion)-en.exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = "https://download.cpuid.com/cpu-z/cpu-z_$($this.CurrentState.RealVersion)-cn.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = $Global:DumplingsStorage.CPUZDownloadPage | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@id='version-history']/div[contains(.//div[@class='version'], '$($this.CurrentState.RealVersion)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          $ReleaseNotesTitleNode.SelectSingleNode('.//div[@class="date"]').InnerText,
          [string[]]@(
            "MMM dd'st', yyyy", "MMMM dd'st', yyyy",
            "MMM dd'nd', yyyy", "MMMM dd'nd', yyyy",
            "MMM dd'rd', yyyy", "MMMM dd'rd', yyyy",
            "MMM dd'th', yyyy", "MMMM dd'th', yyyy"
          ),
          (Get-Culture -Name 'en-US'),
          [System.Globalization.DateTimeStyles]::None
        ).ToString('yyyy-MM-dd')

        # Workarounds to remove download links and their following nodes in release notes
        $ReleaseNotesTitleNode.SelectSingleNode('.//div[@class="release-content"]//div[contains(@class, "links")]').SelectNodes('.|following-sibling::*').ForEach({ $_.Remove() })

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.SelectSingleNode('.//div[@class="release-content"]').ChildNodes[0]; $Node -and -not $Node.HasClass('links'); $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
