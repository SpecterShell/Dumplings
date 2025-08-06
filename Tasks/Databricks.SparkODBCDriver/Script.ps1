$Object1 = Invoke-WebRequest -Uri 'https://www.databricks.com/en-website-assets/page-data/spark/odbc-drivers-download/page-data.json'
# x86
$Object2 = [Newtonsoft.Json.Linq.JObject]::Parse($Object1.Content).SelectTokens('$..[?(@.path =~ /Windows-32bit\.zip$/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json
$VersionX86 = [regex]::Match($Object2.path, '(\d+(?:\.\d+)+)').Groups[1].Value

# x64
$Object3 = [Newtonsoft.Json.Linq.JObject]::Parse($Object1.Content).SelectTokens('$..[?(@.path =~ /Windows-64bit\.zip$/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json
$VersionX64 = [regex]::Match($Object3.path, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: $VersionX64", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64
$MediumVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.path
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object3.path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = @(
        [ordered]@{
          RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.msi') }, 'First')[0].FullName.Replace('/', '\')
        }
      )
      $ZipFile.Dispose()
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = "https://databricks-bi-artifacts.s3.us-east-2.amazonaws.com/simbaspark-drivers/odbc/${MediumVersion}/docs/release-notes.txt"
      }

      $Object4 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)
      while (-not $Object4.EndOfStream) {
        if ($Object4.ReadLine() -match "^$([regex]::Escape($MediumVersion))") {
          break
        }
      }
      if (-not $Object4.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object4.EndOfStream) {
          $String = $Object4.ReadLine()
          if ($String -match '^Released (20\d{2}-\d{1,2}-\d{1,2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } elseif ($String -notmatch '(-|=){3,}$') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
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
