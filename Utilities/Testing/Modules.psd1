@{
  Modules = @(
    @{ Name = 'Pester'; Version = '6.2.0'; RequiredCommands = @('Invoke-Pester') }
    @{ Name = 'PSScriptAnalyzer'; Version = '1.25.0'; RequiredCommands = @('Invoke-ScriptAnalyzer') }
  )
}
