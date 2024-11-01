# x64
$Object1 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10" arch="x64" />
  <app appid="{65E60E95-0DE9-43FF-9F3F-4F7D2DFF04B5}" version="" ap="x64">
    <updatecheck />
  </app>
</request>
'@
$Version1 = $Object1.response.app.updatecheck.manifest.version

# x86
$Object2 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10" arch="x86" />
  <app appid="{65E60E95-0DE9-43FF-9F3F-4F7D2DFF04B5}" version="" ap="x86">
    <updatecheck />
  </app>
</request>
'@
$Version2 = $Object2.response.app.updatecheck.manifest.version

if ($Version1 -ne $Version2) {
  $this.Log("x86 version: ${Version2}")
  $this.Log("x64 version: ${Version1}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Version1

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = ($Object2.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object2.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' }, 'First')[0].run
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = ($Object1.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object1.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' }, 'First')[0].run
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFileX86 = Get-TempFile -Uri $InstallerX86.InstallerUrl
    $NestedInstallerFileX86Root = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${NestedInstallerFileX86Root}" $InstallerFileX86 '2.msi' | Out-Host
    $NestedInstallerFileX86 = Join-Path $NestedInstallerFileX86Root '2.msi'

    $InstallerX86['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX86 -Algorithm SHA256).Hash
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerX86['ProductCode'] = $NestedInstallerFileX86 | Read-ProductCodeFromMsi
        UpgradeCode   = $NestedInstallerFileX86 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

    $InstallerFileX64 = Get-TempFile -Uri $InstallerX64.InstallerUrl
    $NestedInstallerFileX64Root = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${NestedInstallerFileX64Root}" $InstallerFileX64 '2.msi' | Out-Host
    $NestedInstallerFileX64 = Join-Path $NestedInstallerFileX64Root '2.msi'

    $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX64 -Algorithm SHA256).Hash
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerX64['ProductCode'] = $NestedInstallerFileX64 | Read-ProductCodeFromMsi
        UpgradeCode   = $NestedInstallerFileX64 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://support.google.com/earth/answer/40901?hl=en' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[@class='cc']/a[contains(text(), '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'a'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
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

    try {
      $Object4 = Invoke-WebRequest -Uri 'https://support.google.com/earth/answer/40901?hl=zh-Hans' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object4.SelectSingleNode("//div[@class='cc']/a[contains(text(), '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'a'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
