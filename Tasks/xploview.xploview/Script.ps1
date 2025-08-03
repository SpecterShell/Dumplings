$Object1 = Invoke-RestMethod -Uri 'http://www.xploview.com/Cygnus/Proxy' -Method Post -Body @{
  type          = 'text'
  action        = 'get'
  widgetId      = 'SS41499unjWoLeSLb'
  userId        = '0'
  applicationId = 'SS'
}
$Object2 = $Object1.initData.configData.Content | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.Where({ try { $_.outerHTML.Contains('Windows') -and -not $_.outerHTML.Contains('Legacy') } catch {} }, 'First')[0].href | ConvertTo-HtmlDecodedText
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerFileExtracted = New-TempFolder
    Start-Process -FilePath $InstallerFile -ArgumentList @('/extract', $InstallerFileExtracted) -Wait
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'xploview.msi'
    # ProductCode
    $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
