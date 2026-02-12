#region prepare folders
$Current          = (Split-Path -Path $MyInvocation.MyCommand.Path)
$Root             = ((Get-Item $Current).Parent).FullName
$CodeSourcePath   = Join-Path -Path $Root -ChildPath "Code"
$PublicFunctions  = Join-Path $CodeSourcePath -ChildPath 'Public'
$PrivateFunctions = Join-Path $CodeSourcePath -ChildPath 'Private'
$CISourcePath     = Join-Path -Path $Root -ChildPath "CI"
$Settings         = Join-Path -Path $CISourcePath -ChildPath "Module-Settings.json"
#endregion

#region Module-Settings
if([String]::IsNullOrEmpty($ModulePrefix)){
    $ModuleSettings = Get-content -Path $Settings | ConvertFrom-Json
    $ModulePrefix   = $ModuleSettings.ModulePrefix
}
$CommonPrefix = $ModulePrefix
#endregion

#region Load Test Declarations
$DeclarationsPath = Join-Path -Path $Current -ChildPath "declarations.ps1"
if(Test-Path -Path $DeclarationsPath){
    Write-Host "[TEST] Loading test declarations from declarations.ps1" -ForegroundColor Green
    . $DeclarationsPath
}
else{
    Write-Warning "[TEST] declarations.ps1 not found. Please copy declarations_sample.ps1 to declarations.ps1 and configure your test values."
    Write-Warning "[TEST] Integration tests will be skipped."
}
#endregion

BeforeDiscovery {
    $CodeFile = @()
    $CodeFile += Get-ChildItem -Path $PublicFunctions  -Filter "*.ps1"
    $CodeFile += Get-ChildItem -Path $PrivateFunctions -Filter "*.ps1"
}

foreach($file in $CodeFile){

    . ($file.FullName)

    #region variable
    $ScriptName = $file.BaseName
    $Verb = @( $($ScriptName) -split '-' )[0]

    try {
        $FunctionPrefix = @( $ScriptName -split '-' )[1].Substring( 0, $CommonPrefix.Length )
    }
    catch {
        $FunctionPrefix = @( $ScriptName -split '-' )[1]
    }

    $DetailedHelp  = Get-Help $ScriptName -Detailed
    $ScriptCommand = Get-Command -Name $ScriptName -All
    $Ast           = $ScriptCommand.ScriptBlock.Ast
    #endregion

    Describe "Test Code-file $($file.Name)" {

        Context "Naming of $($file.BaseName)" {

            It "$ScriptName should have an approved verb -> $Verb" -TestCases @{ Verb = $Verb} {
                ( $Verb -in @( Get-Verb ).Verb ) | Should -BeTrue
            }

            It "$ScriptName Noun should have the Prefix '$($CommonPrefix)'" -TestCases @{ FunctionPrefix = $FunctionPrefix; CommonPrefix = $CommonPrefix } {
                $FunctionPrefix | Should -Be $CommonPrefix
            }

        }

        Context "Synopsis of $($file.BaseName)" {

            It "$ScriptName should have a SYNOPSIS" -TestCases @{ Ast = $Ast } {
                ( $Ast -match 'SYNOPSIS' ) | Should -BeTrue
            }

            It "$ScriptName should have a DESCRIPTION" -TestCases @{ Ast = $Ast } {
                ( $Ast -match 'DESCRIPTION' ) | Should -BeTrue
            }

            It "$ScriptName should have a EXAMPLE" -TestCases @{ Ast = $Ast } {
                ( $Ast -match 'EXAMPLE' ) | Should -BeTrue
            }

        }

        Context "Parameters of $($file.BaseName)" {

            It "$($file.Name) should have a function named $($file.BaseName)" -TestCases @{ Ast = $Ast; ScriptName = $ScriptName } {
                ($Ast -match $ScriptName) | Should -be $true
            }

            It "$ScriptName should have a CmdletBinding" -TestCases @{ Ast = $Ast } {
                [boolean]( @( $Ast.FindAll( { $true } , $true ) ) | Where-Object { $_.TypeName.Name -eq 'cmdletbinding' } ) | Should -Be $true
            }

            $DefaultParams = @( 'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'ProgressAction')
            foreach ( $p in @( $ScriptCommand.Parameters.Keys | Where-Object { $_ -notin $DefaultParams } | Sort-Object ) ) {

                It "$ScriptName the Help-text for paramater '$( $p )' should exist" {
                    ( $p -in $DetailedHelp.parameters.parameter.name ) | Should -Be $true
                }
                $Declaration = ( ( @( $Ast.FindAll( { $true } , $true ) ) | Where-Object { $_.Name.Extent.Text -eq "$('$')$p" } ).Extent.Text -replace 'INT32', 'INT' )
                #$VariableType = ( "\[$( $ScriptCommand.Parameters."$p".ParameterType.Name )\]" -replace 'INT32', 'INT' )
                $VariableTypeFull = "\[$( $ScriptCommand.Parameters."$p".ParameterType.FullName )\]"
                $VariableType = $ScriptCommand.Parameters."$p".ParameterType.Name
                $VariableType = $VariableType -replace 'INT32', 'INT'
                $VariableType = $VariableType -replace 'Int64', 'long'
                $VariableType = $VariableType -replace 'String\[\]', 'String'
                $VariableType = $VariableType -replace 'SwitchParameter', 'Switch'

                # Escape regex special characters in type names (e.g., [] in array types)
                $VariableTypeEscaped = [regex]::Escape($VariableType)
                $VariableTypeFullEscaped = [regex]::Escape($VariableTypeFull)

                It "$ScriptName type '[$( $ScriptCommand.Parameters."$p".ParameterType.Name )]' should be declared for parameter '$( $p )'" {
                    ( ( $Declaration -match $VariableTypeEscaped ) -or ( $Declaration -match $VariableTypeFullEscaped ) ) | Should -Be $true
                }
            }

        }
    }

}
