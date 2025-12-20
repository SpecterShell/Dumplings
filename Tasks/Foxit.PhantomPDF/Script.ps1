$Object1 = Invoke-RestMethod -Uri 'https://www.foxit.com/portal/download/getdownloadform.html?retJson=1&platform=Windows&formId=download-phantom-bussiness'

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = 'https://cdn01.foxitsoftware.com' + $Object1.package_info.down.Replace('_Website', '')
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

    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.msi' '3.msp' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '2.msi'
    $InstallerFile3 = Join-Path $InstallerFileExtracted '3.msp'
    $Params = @{}
    if (Test-Path -Path $InstallerFile3) { $Params['PatchPath'] = $InstallerFile3 }
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi @Params
    # ProductCode
    $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi @Params
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
