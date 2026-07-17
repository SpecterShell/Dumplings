@{
  Modules = @(
    @{
      Name             = 'PowerHTML'
      Version          = '0.2.0'
      RequiredCommands = @('ConvertFrom-Html')
    }
    @{
      Name             = 'powershell-yaml'
      Version          = '0.4.12'
      RequiredCommands = @('ConvertFrom-Yaml', 'ConvertTo-Yaml')
    }
  )
}
