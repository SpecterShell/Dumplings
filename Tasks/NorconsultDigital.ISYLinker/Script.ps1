$Object1 = Invoke-WebRequest -Uri 'https://norconsultdigital.no/produkter/isy-linker/'

$VersionX86 = [regex]::Match($Object1.Content, 'ISY Linker.+?v\. (\d+(?:\.\d+)+)').Groups[1].Value
# $VersionX64 = [regex]::Match($Object1.Content, 'ISY Linker 64bit.+?v\. (\d+(?:\.\d+)+)').Groups[1].Value

# if ($VersionX86 -ne $VersionX64) {
#   $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
#   return
# }

# Version
$this.CurrentState.Version = $VersionX86

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = ''
# }
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x64'
#   InstallerUrl = ''
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Get-ChildItem -Path $InstallerFileExtracted -Include 'ISY Linker*.msi' -Recurse | Select-Object -First 1
      # ProductCode
      $Installer.ProductCode = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer.AppsAndFeaturesEntries = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Log('This package requires manual submission. Get the installer from the website.', 'Warning')
  }
}
