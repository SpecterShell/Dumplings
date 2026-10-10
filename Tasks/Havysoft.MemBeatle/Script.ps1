$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'inno'
  InstallerUrl        = 'https://www.havysoft.cl/download/MB_Install.zip'
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'LastModified'
    ReadVersion = {
      param($Path)
      $Extracted = Expand-TempArchive -Path $Path -RelativeFilePath 'MB_Install.exe' -CollisionAction Rename
      try {
        Read-FileVersionFromExe -Path (Join-Path $Extracted 'MB_Install.exe')
      } finally {
        Remove-Item -LiteralPath $Extracted -Recurse -Force -ErrorAction Continue -ProgressAction SilentlyContinue
      }
    }
  })
$this.CompleteInstallerUpdates($Result)
