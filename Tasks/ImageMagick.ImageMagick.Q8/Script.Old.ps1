$Prefix = 'https://imagemagick.org/archive/binaries/'

$InstallerObjects = $Global:DumplingsStorage.ImageMagickFileList.RDF.Content |
  Where-Object -FilterScript { $_.about -match '\.(exe|zip)' -and $_.about.Contains('Q8') -and -not $_.about.Contains('HDRI') } |
  Sort-Object -Property { $_.about -replace '\d+', { $_.Value.PadLeft(20) } }

$InstallerObjectX86 = $InstallerObjects.Where({ $_.about.Contains('x86') -and $_.about.Contains('dll') }, 'Last')[0]
$VersionX86 = [regex]::Match($InstallerObjectX86.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

$InstallerObjectX64 = $InstallerObjects.Where({ $_.about.Contains('x64') -and $_.about.Contains('dll') }, 'Last')[0]
$VersionX64 = [regex]::Match($InstallerObjectX64.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

$InstallerObjectArm64 = $InstallerObjects.Where({ $_.about.Contains('arm64') -and $_.about.Contains('dll') }, 'Last')[0]
$VersionArm64 = [regex]::Match($InstallerObjectArm64.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

$InstallerObjectZipX86 = $InstallerObjects.Where({ $_.about.Contains('x86') -and $_.about.Contains('portable') }, 'Last')[0]
$VersionZipX86 = [regex]::Match($InstallerObjectZipX86.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

$InstallerObjectZipX64 = $InstallerObjects.Where({ $_.about.Contains('x64') -and $_.about.Contains('portable') }, 'Last')[0]
$VersionZipX64 = [regex]::Match($InstallerObjectZipX64.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

$InstallerObjectZipArm64 = $InstallerObjects.Where({ $_.about.Contains('arm64') -and $_.about.Contains('portable') }, 'Last')[0]
$VersionZipArm64 = [regex]::Match($InstallerObjectZipArm64.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value

# $Object2 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/ImageMagick/ImageMagick/releases/latest'
# $VersionMSIX = $Object2.tag_name -creplace '^v'

# if (@(@($VersionX86, $VersionX64, $VersionArm64, $VersionMSIX, $VersionZipX86, $VersionZipX64, $VersionZipArm64) | Sort-Object -Unique).Count -gt 1) {
#   throw 'Inconsistent versions detected'
# }

if (@(@($VersionX86, $VersionX64, $VersionArm64, $VersionZipX86, $VersionZipX64, $VersionZipArm64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inno x86 version: ${VersionX86}")
  $this.Log("Inno x64 version: ${VersionX64}")
  $this.Log("Inno arm64 version: ${VersionArm64}")
  $this.Log("Portable x86 version: ${VersionZipX86}")
  $this.Log("Portable x64 version: ${VersionZipX64}")
  $this.Log("Portable arm64 version: ${VersionZipArm64}")
  throw 'Inconsistent versions detected'
}

$Version = @($VersionX86, $VersionX64, $VersionArm64, $VersionZipX86, $VersionZipX64, $VersionZipArm64) | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1
$Commands = @('compare', 'composite', 'conjure', 'convert', 'identify', 'magick', 'mogrify', 'montage', 'stream')

# Version
$this.CurrentState.Version = $Version.Replace('-', '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x86'
  InstallerType   = 'inno'
  InstallerUrl    = $Prefix + $InstallerObjectX86.about
  InstallerSha256 = $InstallerObjectX86.sha256.ToUpper()
  ProductCode     = "ImageMagick $($Version.Split('-')[0]) Q8 (32-bit)_is1"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerType   = 'inno'
  InstallerUrl    = $Prefix + $InstallerObjectX64.about
  InstallerSha256 = $InstallerObjectX64.sha256.ToUpper()
  ProductCode     = "ImageMagick $($Version.Split('-')[0]) Q8 (64-bit)_is1"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  InstallerType   = 'inno'
  InstallerUrl    = $Prefix + $InstallerObjectArm64.about
  InstallerSha256 = $InstallerObjectArm64.sha256.ToUpper()
  ProductCode     = "ImageMagick $($Version.Split('-')[0]) Q8 (arm64)_is1"
}
# $this.CurrentState.Installer += [ordered]@{
#   InstallerType = 'msix'
#   InstallerUrl  = $Object2.assets.Where({ $_.name.EndsWith('.msixbundle') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerType        = 'zip'
  NestedInstallerFiles = $Commands | ForEach-Object -Process {
    [ordered]@{
      RelativeFilePath     = "$(Split-Path -Path $InstallerObjectZipX86.about -LeafBase)\${_}.exe"
      PortableCommandAlias = $_
    }
  }
  InstallerUrl         = $Prefix + $InstallerObjectZipX86.about
  InstallerSha256      = $InstallerObjectZipX86.sha256.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerFiles = $Commands | ForEach-Object -Process {
    [ordered]@{
      RelativeFilePath     = "$(Split-Path -Path $InstallerObjectZipX64.about -LeafBase)\${_}.exe"
      PortableCommandAlias = $_
    }
  }
  InstallerUrl         = $Prefix + $InstallerObjectZipX64.about
  InstallerSha256      = $InstallerObjectZipX64.sha256.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  InstallerType        = 'zip'
  NestedInstallerFiles = $Commands | ForEach-Object -Process {
    [ordered]@{
      RelativeFilePath     = "$(Split-Path -Path $InstallerObjectZipArm64.about -LeafBase)\${_}.exe"
      PortableCommandAlias = $_
    }
  }
  InstallerUrl         = $Prefix + $InstallerObjectZipArm64.about
  InstallerSha256      = $InstallerObjectZipArm64.sha256.ToUpper()
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
