$Prefix = 'https://www.python.org/ftp/python/'

$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Version = (
  $Object1.SelectNodes('/html/body/pre/a').ForEach({ $_.Attributes['href'].Value }) |
    Select-String -Pattern '3\.12\.\d+/' -Raw |
    Sort-Object -Property { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } |
    Select-Object -Last 1
).Replace('/', '')

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "${Prefix}${Version}/python-${Version}.exe"
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${Prefix}${Version}/python-${Version}-amd64.exe"
}
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "${Prefix}${Version}/python-${Version}-arm64.exe"
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = "https://docs.python.org/release/${Version}/whatsnew/changelog.html"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # AppsAndFeaturesEntries
    $InstallerFileX86 = Get-TempFile -Uri $InstallerX86.InstallerUrl
    $InstallerFileX64 = Get-TempFile -Uri $InstallerX64.InstallerUrl
    $InstallerFileARM64 = Get-TempFile -Uri $InstallerARM64.InstallerUrl

    $RealVersion = $InstallerFileX64 | Read-ProductVersionFromExe

    $InstallerX86['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX86 -Algorithm SHA256).Hash
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = "Python ${Version} (32-bit)"
        DisplayVersion = $RealVersion
        ProductCode    = $InstallerX86['ProductCode'] = $InstallerFileX86 | Read-ProductCodeFromBurn
        UpgradeCode    = $InstallerFileX86 | Read-UpgradeCodeFromBurn
      }
    )

    $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX64 -Algorithm SHA256).Hash
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = "Python ${Version} (64-bit)"
        DisplayVersion = $RealVersion
        ProductCode    = $InstallerX64['ProductCode'] = $InstallerFileX64 | Read-ProductCodeFromBurn
        UpgradeCode    = $InstallerFileX64 | Read-UpgradeCodeFromBurn
      }
    )

    $InstallerARM64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileARM64 -Algorithm SHA256).Hash
    $InstallerARM64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = "Python ${Version} (ARM64)"
        DisplayVersion = $RealVersion
        ProductCode    = $InstallerARM64['ProductCode'] = $InstallerFileARM64 | Read-ProductCodeFromBurn
        UpgradeCode    = $InstallerFileARM64 | Read-UpgradeCodeFromBurn
      }
    )

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='python-$($Version.Replace('.', '-'))-final']")

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $ReleaseNotesNode.SelectSingleNode('./p[1]//text()').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = ($ReleaseNotesNode.SelectNodes('./p[1]/following-sibling::node()') | Get-TextContent | Format-Text).Replace('¶', '')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
