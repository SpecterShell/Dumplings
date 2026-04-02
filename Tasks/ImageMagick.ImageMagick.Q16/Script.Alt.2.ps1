$Prefix = 'https://imagemagick.org/archive/binaries/'

$InstallerObjects = $Global:DumplingsStorage.ImageMagickFileList.RDF.Content |
  Where-Object -FilterScript { $_.about -match '\.(exe|zip)' -and $_.about.Contains('Q16') -and -not $_.about.Contains('HDRI') } |
  Sort-Object -Property { $_.about -replace '\d+', { $_.Value.PadLeft(20) } }

$InstallerObjectX86 = $InstallerObjects.Where({ $_.about.Contains('x86') -and $_.about.Contains('dll') }, 'Last')[0]
$VersionX86 = [regex]::Match($InstallerObjectX86.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

$InstallerObjectX64 = $InstallerObjects.Where({ $_.about.Contains('x64') -and $_.about.Contains('dll') }, 'Last')[0]
$VersionX64 = [regex]::Match($InstallerObjectX64.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

$InstallerObjectArm64 = $InstallerObjects.Where({ $_.about.Contains('arm64') -and $_.about.Contains('dll') }, 'Last')[0]
$VersionArm64 = [regex]::Match($InstallerObjectArm64.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

if (@(@($VersionX86, $VersionX64, $VersionArm64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inno x86 version: ${VersionX86}")
  $this.Log("Inno x64 version: ${VersionX64}")
  $this.Log("Inno arm64 version: ${VersionArm64}")
  throw 'Inconsistent versions detected'
}

$Version = @($VersionX86, $VersionX64, $VersionArm64) | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Version.Replace('-', '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x86'
  InstallerType   = 'inno'
  InstallerUrl    = $Prefix + $InstallerObjectX86.about
  InstallerSha256 = $InstallerObjectX86.sha256.ToUpper()
  ProductCode     = "ImageMagick $($Version.Split('-')[0]) Q16 (32-bit)_is1"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerType   = 'inno'
  InstallerUrl    = $Prefix + $InstallerObjectX64.about
  InstallerSha256 = $InstallerObjectX64.sha256.ToUpper()
  ProductCode     = "ImageMagick $($Version.Split('-')[0]) Q16 (64-bit)_is1"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  InstallerType   = 'inno'
  InstallerUrl    = $Prefix + $InstallerObjectArm64.about
  InstallerSha256 = $InstallerObjectArm64.sha256.ToUpper()
  ProductCode     = "ImageMagick $($Version.Split('-')[0]) Q16 (arm64)_is1"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = 'https://github.com/ImageMagick/Website/blob/main/ChangeLog.md'
      }

      $Object3 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/ImageMagick/Website/main/ChangeLog.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("/h2[contains(.//text(), '${Version}')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
