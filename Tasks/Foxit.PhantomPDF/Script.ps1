$Object1 = Invoke-RestMethod -Uri 'https://www.foxit.com/portal/download/getdownloadform.html?retJson=1&platform=Windows&formId=download-phantom-bussiness'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = 'https://cdn01.foxitsoftware.com' + $Object1.package_info.down.Replace('_Website', '')
}
$this.CurrentState.Installer += $InstallerWiX = [ordered]@{
  InstallerType       = 'zip'
  NestedInstallerType = 'wix'
  InstallerUrl        = 'https://cdn01.foxitsoftware.com' + $Object1.package_info.down.Replace('_Website', '').Replace('.exe', '.zip')
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.package_info.release, 'MM/dd/yy', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$InstallerWiX.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerWiX.InstallerUrl
    $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
    $InstallerWiX['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.msi') }, 'First')[0].FullName.Replace('/', '\') })
    $ZipFile.Dispose()
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $InstallerWiX.NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $InstallerWiX.NestedInstallerFiles[0].RelativeFilePath
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.foxit.com/pdf-editor/version-history.html' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[@id='tab-editor-windows']//div[@id='version_$($this.CurrentState.RealVersion)_detail']")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNode.SelectSingleNode('./p[.//a[@class="download"]]') ?? $ReleaseNotesNode.SelectSingleNode('./p[1]') ?? $ReleaseNotesNode.SelectSingleNode('./div/p[.//a[@class="download"]]') ?? $ReleaseNotesNode.SelectSingleNode('./div/p[1]')).SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
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
