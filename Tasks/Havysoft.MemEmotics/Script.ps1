$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'inno'
  InstallerUrl        = 'https://www.havysoft.cl/download/ME_Install.zip'
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'LastModified'
    ReadVersion = {
      param($Path)
      $Extracted = Expand-TempArchive -Path $Path -RelativeFilePath 'ME_Install.exe' -CollisionAction Rename
      try {
        Read-FileVersionFromExe -Path (Join-Path $Extracted 'ME_Install.exe')
      } finally {
        Remove-Item -LiteralPath $Extracted -Recurse -Force -ErrorAction Continue -ProgressAction SilentlyContinue
      }
    }
  })
$this.CompleteInstallerUpdates($Result)
