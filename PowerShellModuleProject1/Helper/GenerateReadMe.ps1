#
# GenerateReadMe.ps1
#
Import-Module $PSScriptRoot\..\ABFunctions.psm1 -Force -verbose -Debug
Get-MarkDownFileForCmdLets -Module ABFunctions -OutputFileName "$PSScriptRoot\..\..\ReadMe.md" -ReadMeMarkdownHeaderFileName "$PSScriptRoot\..\..\ReadMeHeader.md" 