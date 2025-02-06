BeforeAll {
  Add-Type -Path (Join-Path $PSScriptRoot 'Versioning.cs')
}

Describe 'Chunk' {
  It 'Should return the correct numeric Chunk #1' {
    $Chunk = [Versioning.Chunk]::Parse('123')
    $Chunk.Type | Should -Be 'Numeric'
    $Chunk.Alphanum | Should -Be '123'
    $Chunk.Numeric | Should -Be 123
  }
  It 'Should return the correct alphanum Chunk #1' {
    $Chunk = [Versioning.Chunk]::Parse('123a')
    $Chunk.Type | Should -Be 'Alphanum'
    $Chunk.Alphanum | Should -Be '123a'
    $Chunk.Numeric | Should -Be $null
  }
  It 'Should return the correct alphanum Chunk #2' {
    $Chunk = [Versioning.Chunk]::Parse('123-456')
    $Chunk.Type | Should -Be 'Alphanum'
    $Chunk.Alphanum | Should -Be '123-456'
    $Chunk.Numeric | Should -Be $null
  }
  It 'Should return the correct alphanum Chunk #3' {
    $Chunk = [Versioning.Chunk]::Parse('00a')
    $Chunk.Type | Should -Be 'Alphanum'
    $Chunk.Alphanum | Should -Be '00a'
    $Chunk.Numeric | Should -Be $null
  }
}

Describe 'ComplexChunk' {
  It 'Should return the correct digits ComplexChunk #1' {
    $Chunk = [Versioning.ComplexChunk]::Parse('1')
    $Chunk.Type | Should -Be 'Digits'
    $Chunk.Alphanum | Should -Be '1'
    $Chunk.Numeric | Should -Be 1
  }
  It 'Should return the correct digits ComplexChunk #2' {
    $Chunk = [Versioning.ComplexChunk]::Parse('01')
    $Chunk.Type | Should -Be 'Digits'
    $Chunk.Alphanum | Should -Be '01'
    $Chunk.Numeric | Should -Be 1
  }
  It 'Should return the correct digits ComplexChunk #3' {
    $Chunk = [Versioning.ComplexChunk]::Parse('987')
    $Chunk.Type | Should -Be 'Digits'
    $Chunk.Alphanum | Should -Be '987'
    $Chunk.Numeric | Should -Be 987
  }
  It 'Should return the correct rev ComplexChunk #1' {
    $Chunk = [Versioning.ComplexChunk]::Parse('r1')
    $Chunk.Type | Should -Be 'Rev'
    $Chunk.Alphanum | Should -Be 'r1'
    $Chunk.Numeric | Should -Be 1
  }
  It 'Should return the correct rev ComplexChunk #2' {
    $Chunk = [Versioning.ComplexChunk]::Parse('r01')
    $Chunk.Type | Should -Be 'Rev'
    $Chunk.Alphanum | Should -Be 'r01'
    $Chunk.Numeric | Should -Be 1
  }
  It 'Should return the correct rev ComplexChunk #3' {
    $Chunk = [Versioning.ComplexChunk]::Parse('r987')
    $Chunk.Type | Should -Be 'Rev'
    $Chunk.Alphanum | Should -Be 'r987'
    $Chunk.Numeric | Should -Be 987
  }
  It 'Should return the correct plain ComplexChunk #1' {
    $Chunk = [Versioning.ComplexChunk]::Parse('abcd')
    $Chunk.Type | Should -Be 'Plain'
    $Chunk.Alphanum | Should -Be 'abcd'
    $Chunk.Numeric | Should -Be $null
  }
  It 'Should return the correct plain ComplexChunk #2' {
    $Chunk = [Versioning.ComplexChunk]::Parse('1r3')
    $Chunk.Type | Should -Be 'Plain'
    $Chunk.Alphanum | Should -Be '1r3'
    $Chunk.Numeric | Should -Be $null
  }
  It 'Should return the correct plain ComplexChunk #3' {
    $Chunk = [Versioning.ComplexChunk]::Parse('alpha0')
    $Chunk.Type | Should -Be 'Plain'
    $Chunk.Alphanum | Should -Be 'alpha0'
    $Chunk.Numeric | Should -Be $null
  }
}

Describe 'ComplexVersion' {
  It 'Should return the correct ComplexVersion' {
    $Version = [Versioning.ComplexVersion]::Parse('1')
    $Version.Type | Should -Be 'Complex'
    $Version.ChunkGroups.Count | Should -Be 1
    $Version.ChunkGroups[0].Type | Should -Be 'Digits'
    $Version.ChunkGroups[0].Alphanum | Should -Be '1'
    $Version.ChunkGroups[0].Numeric | Should -Be 1
  }
}

Describe 'SemanticVersion' {
  It 'Should return the correct SemanticVersion #1' {
    @(
      '0.1.0'
      '1.2.3'
      '1.2.3-1'
      '1.2.3-alpha'
      '1.2.3-alpha.2'
      '1.2.3+a1b2c3.1'
      '1.2.3-alpha.2+a1b2c3.1'
      '1.0.0-x-y-z.-'
      '1.0.0-alpha+001'
      '1.0.0+21AF26D3---117B344092BD'
    ) | ForEach-Object -Process { { [Versioning.SemanticVersion]::Parse($_) } | Should -Not -Throw }
  }
  It 'Should return the correct SemanticVersion #2' {
    @(
      '0.4.8-1'
      '7.42.13-4'
      '2.1.16102-2'
      '2.2.1-b05'
      '1.11.0+20200830-1'
    ) | ForEach-Object -Process { { [Versioning.SemanticVersion]::Parse($_) } | Should -Not -Throw }
  }
  It 'Should return the correct SemanticVersion #3' {
    [Versioning.SemanticVersion]::Parse('1.2.2-00a')
  }
  It 'Should throw error when parsing into SemanticVersion' {
    @(
      '1'
      '1.2'
      'a.b.c'
      '1.01.1'
      '1.2.3+a1b!2c3.1'
      ''
      '1.2.3 '
    ) | ForEach-Object -Process { { [Versioning.SemanticVersion]::Parse($_) } | Should -Throw }
  }
  It 'Should correctly order the SemanticVersion instances' {
    $Versions = @(
      '1.0.0-alpha'
      '1.0.0-alpha.1'
      # '1.0.0-alpha.beta'
      '1.0.0-beta'
      '1.0.0-beta.2'
      '1.0.0-beta.11'
      '1.0.0-rc.1'
      '1.0.0'
    )
    for ($i = 0; $i -lt $Versions.Count - 1; $i++) {
      for ($j = $i + 1; $j -lt $Versions.Count; $j++) {
        [Versioning.SemanticVersion]::Parse($Versions[$i]) -lt [Versioning.SemanticVersion]::Parse($Versions[$j]) | Should -Be $true
        [Versioning.SemanticVersion]::Parse($Versions[$j]) -gt [Versioning.SemanticVersion]::Parse($Versions[$i]) | Should -Be $true
      }
    }
  }
}

Describe 'GeneralVersion' {
  It 'Should return the correct GeneralVersion' {
    @(
      '1'
      '1.2'
      '1.0rc0'
      '1.0rc1'
      '1.1rc1'
      '44.0.2403.157-1'
      '0.25-2'
      '8.u51-1'
      '21-2'
      '7.1p1-1'
      '20150826-1'
      '1:0.10.16-3'
      '8.64.0.81-1'
      '1:3.20-1'
    ) | ForEach-Object -Process {
      { [Versioning.SemanticVersion]::Parse($_) } | Should -Throw
      { [Versioning.GeneralVersion]::Parse($_) } | Should -Not -Throw
    }
  }
  It 'Should throw error when parsing into GeneralVersion' {
    @(
      ''
      '1.2 '
    ) | ForEach-Object -Process { { [Versioning.GeneralVersion]::Parse($_) } | Should -Throw }
  }
  It 'Should correctly order the GeneralVersion instances #1' {
    $Versions = @(
      '0.9.9.9'
      '1.0.0.0'
      '1.0.0.1'
      '2'
    )
    for ($i = 0; $i -lt $Versions.Count - 1; $i++) {
      for ($j = $i + 1; $j -lt $Versions.Count; $j++) {
        [Versioning.GeneralVersion]::Parse($Versions[$i]) -lt [Versioning.GeneralVersion]::Parse($Versions[$j]) | Should -Be $true
        [Versioning.GeneralVersion]::Parse($Versions[$j]) -gt [Versioning.GeneralVersion]::Parse($Versions[$i]) | Should -Be $true
      }
    }
  }
  It 'Should correctly order the GeneralVersion instances #2' {
    [Versioning.GeneralVersion]::Parse('1.2-5') -lt [Versioning.GeneralVersion]::Parse('1.2.3-1') | Should -Be $true
    # [Versioning.GeneralVersion]::Parse('1.0rc1') -lt [Versioning.GeneralVersion]::Parse('1.0') | Should -Be $true
    [Versioning.GeneralVersion]::Parse('1.0') -lt [Versioning.GeneralVersion]::Parse('1:1.0') | Should -Be $true
    [Versioning.GeneralVersion]::Parse('1.1') -lt [Versioning.GeneralVersion]::Parse('1:1.0') | Should -Be $true
    [Versioning.GeneralVersion]::Parse('1.1') -lt [Versioning.GeneralVersion]::Parse('1:1.1') | Should -Be $true
  }
}
