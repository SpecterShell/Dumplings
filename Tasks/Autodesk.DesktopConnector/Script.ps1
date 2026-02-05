$Object1 = Invoke-WebRequest -Uri 'https://up.autodesk.com/2017/CDX/OFFL-UPDATER-V3.xml' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.UpdateInformation.Constants.Constant.Where({ $_.Name -eq 'LatestVersionPhase1' }, 'First')[0].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://up.autodesk.com/2017/CDX/AB4AADCC-F890-4B4F-A7A6-B0FBD2386796/DesktopConnector-x64-$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $Object2 = 7z.exe e -y -so $InstallerFile 'db-bootstrap.json' | ConvertFrom-Json
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $Object2.FileInfo[0].File | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted $Object2.FileInfo[0].File
      $Object3 = 7z.exe e -y -so $InstallerFile2 'setup.xml' | ConvertFrom-Xml
      # ProductCode
      $Installer['ProductCode'] = $Object3.Bundle.Identity.UPI2

      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://help.autodesk.com/cloudhelp/ENU/CONNECT-Release-Notes/files/GUID-03D59AAD-65B0-45E3-84F2-A12AAA5BB267.htm' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # Remove "Related resources" and its following nodes
        $Object2.SelectNodes("//*[(self::h3 and contains(., 'Related resources')) or @id='strong-related-resources-strong']").SelectNodes('.|./following-sibling::node()').ForEach({ $_.Remove() })
        # Remove download button
        $Object2.SelectNodes("//a[contains(@class, 'download-button')]").ForEach({ $_.Remove() })
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

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://help.autodesk.com/cloudhelp/CHS/CONNECT-Release-Notes/files/GUID-03D59AAD-65B0-45E3-84F2-A12AAA5BB267.htm' | ConvertFrom-Html

      $ReleaseNotesCNTitleNode = $Object3.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNTitleNode) {
        # Remove "Related resources" and its following nodes
        $Object3.SelectNodes("//*[(self::h3 and contains(., '相关资源')) or @id='strong-related-resources-strong']").SelectNodes('.|./following-sibling::node()').ForEach({ $_.Remove() })
        # Remove download button
        $Object3.SelectNodes("//a[contains(@class, 'download-button')]").ForEach({ $_.Remove() })
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
