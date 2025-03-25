# x86
$Object1 = Invoke-RestMethod -Uri 'https://www.high-logic.com/process.php' -Body @{
  plt = 'win'
  tar = 'x86'
  app = 'mt'
  ver = $this.Status.Contains('New') ? '12.0.0.1337' : $this.LastState.Version
  lid = '0'
  mod = '0'
}

if ($Object1.versioninfo.haveupdate -eq 'false') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# x64
$Object2 = Invoke-RestMethod -Uri 'https://www.high-logic.com/process.php' -Body @{
  plt = 'win'
  tar = 'x64'
  app = 'mt'
  ver = $this.Status.Contains('New') ? '12.0.0.1337' : $this.LastState.Version
  lid = '0'
  mod = '0'
}

if ($Object2.versioninfo.haveupdate -eq 'false') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

if ($Object1.versioninfo.installer.version -ne $Object2.versioninfo.installer.version) {
  $this.Log("x86 version: $($Object1.versioninfo.installer.version)")
  $this.Log("x64 version: $($Object2.versioninfo.installer.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.versioninfo.installer.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.versioninfo.installer.url | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.versioninfo.installer.url | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.high-logic.com/font-manager/maintype/changelog' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//li[@class='el-item' and contains(.//h3[contains(@class, 'el-title')], 'MainType $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('.//h3[contains(@class, "el-title")]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('.//div[contains(@class, "el-content")]') | Get-TextContent | Format-Text
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
