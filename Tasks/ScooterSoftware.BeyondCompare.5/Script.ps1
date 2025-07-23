$Object1 = Invoke-RestMethod -Uri 'https://www.scootersoftware.com/checkupdates.php?product=bc5&lang=silent'

# Version
$this.CurrentState.Version = $Object1.Update.latestversion -replace '\s+build\s+', '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-de-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'fr'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-fr-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ja'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-jp-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-zh-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'cs'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-cs-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'es'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-es-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ga'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-ga-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'id'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-id-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'it'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-it-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ko'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-kr-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'nl'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-nl-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'pt'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-pt-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ru'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-ru-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'sl'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-sl-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'sv'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-se-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-TW'
  InstallerUrl    = "https://www.scootersoftware.com/files/BCompare-cn-$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.scootersoftware.com/download/v5changelog' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='changelog']/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+\d{1,4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
