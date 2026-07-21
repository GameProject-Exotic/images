#Requires -Version 7

# Extract-ImageColor
#
# Copyright (C) 2026  anominy
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

param(
    [Alias('SourceDirectory', 'SourceDir', 'SrcDir', 'Source', 'Src', 'S')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$SourceDirectoryPath = [NullString]::Value,

    [Alias('OutputFile', 'OutFile', 'Output', 'Out', 'O')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$OutputFilePath = [NullString]::Value,

    [Alias('ExcludeFile', 'Exclude', 'E')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$ExcludeFilePath = [NullString]::Value,

    [Alias('SampleCount', 'C')]
    [AllowNull()]
    [Nullable[int]]$SampleColorCount = $null
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

Set-StrictMode -Version 3.0

[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('en-US')

Import-Module -Name (Join-Path $PSScriptRoot "$([IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)).psm1") -Scope Local -Force


if (-Not (Test-SourceDirectoryPath $SourceDirectoryPath)) {
    $SourceDirectoryPath = $DefaultSourceDirectoryPath
}
if (-Not (Test-OutputFilePath $OutputFilePath)) {
    $OutputFilePath = $DefaultOutputFilePath
}
if (-Not (Test-ExcludeFilePath $ExcludeFilePath)) {
    $ExcludeFilePath = $DefaultExcludeFilePath
}
if (-Not (Test-SampleColorCount $SampleColorCount)) {
    $SampleColorCount = $DefaultSampleColorCount
}


if (-Not (Test-Path -LiteralPath $SourceDirectoryPath -PathType Container)) {
    throw Get-InvalidDirectoryPathErrorMessage(Get-NameOf { $SourceDirectoryPath })
}
if (-Not (Test-Path -LiteralPath $OutputFilePath -IsValid)) {
    throw Get-InvalidFilePathErrorMessage(Get-NameOf { $OutputFilePath })
}

[string[]]$excludes = @()
if (Test-Path -LiteralPath $ExcludeFilePath -PathType Leaf) {
    $excludes = [IO.File]::ReadAllLines($ExcludeFilePath) | ForEach-Object { $_.Trim() }
    $excludes = $excludes.Where({ $_ -Ne '' })
}

[object[]]$includes = Get-ChildItem -LiteralPath $SourceDirectoryPath -Filter '*.jpg' -File -Force
if ($excludes.Count -Ne 0) {
    $includes = $includes.Where({ $_.BaseName -NotIn $excludes })
}
if ($includes.Count -Eq 0) {
    Write-Warning 'He~y.. You forgot to put somw images! No~o, not the cat~ ones..'
    return
}

$PSStyle.Progress.Style = $ProgressStyle
$PSStyle.Progress.View = $ProgressView

[int]$progress = 0
[object[]]$objects = $includes | ForEach-Object {
    Write-Progress -Id $ProgressImageProcessId `
        -Activity $ProgressImageProcessActivity `
        -Status ($ProgressImageProcessStatus -F $_.BaseName) `
        -PercentComplete (($progress + 1) / $includes.Count * 100)

    [object[]]$colors = magick $_.FullName +dither -colors $SampleColorCount -format '%c' histogram:info:- `
        | ForEach-Object {
            $m = $ColorHistogramRegex.Match($_)
            if (-Not $m.Success) {
                return
            }

            $g = $m.Groups

            [int]$count = $g[$ColorHistogramCountRegexGroup].Value
            [float]$red = $g[$ColorHistogramRedComponentRegexGroup].Value
            [float]$green = $g[$ColorHistogramGreenComponentRegexGroup].Value
            [float]$blue = $g[$ColorHistogramBlueComponentRegexGroup].Value
            [float]$weight = ($red * $count + $green * $count + $blue * $count) / 3

            [PSCustomObject]@{
                Red = $red
                Green = $green
                Blue = $blue
                Weight = $weight
            }
        }

    [float]$red = 0
    [float]$green = 0
    [float]$blue = 0

    [float]$weight = ($colors | Measure-Object Weight -Sum).Sum
    if ($weight -Ne 0) {
        $red = ($colors | ForEach-Object { $_.Red * $_.Weight } | Measure-Object -Sum).Sum / $weight
        $green = ($colors | ForEach-Object { $_.Green * $_.Weight } | Measure-Object -Sum).Sum / $weight
        $blue = ($colors | ForEach-Object { $_.Blue * $_.Weight } | Measure-Object -Sum).Sum / $weight
    }

    [string[]]$hvals = Convert-ToHex $red $green $blue

    [string]$hred = $hvals[0]
    [string]$hgreen = $hvals[1]
    [string]$hblue = $hvals[2]

    [string]$hex = [string]::Join('', $hvals)

    [float[]]$hsb = Convert-ToHsb $red $green $blue
    [float]$hue = $hsb[0]
    [float]$saturation = $hsb[1]
    [float]$brightness = $hsb[2]

    [int]$value = [Convert]::ToInt32($hex, 16)

    ++$progress

    [PSCustomObject]@{
        Map = $_.BaseName
        Value = $value
        Hex = $hex
        Red = $red
        Green = $green
        Blue = $blue
        'Red Hex' = $hred
        'Green Hex' = $hgreen
        'Blue Hex' = $hblue
        Hue = $hue
        Saturation = $saturation
        Brightness = $brightness
    }
}

$enthash = [PSCustomObject]@{}
if (Test-Path -LiteralPath $OutputFilePath -PathType Leaf) {
    $enthash =  Get-Content -LiteralPath $OutputFilePath -Raw `
        | ConvertFrom-Json
}

$objhash = [PSCustomObject]@{}
$objects | ForEach-Object {
    $props = $_ | Select-Object -Property '*' -ExcludeProperty 'Map'
    $objhash | Add-Member -MemberType NoteProperty -Name $_.Map -Value $props
}

$exchash = [PSCustomObject]@{}
$enthash.PSObject.Properties | ForEach-Object {
    $exchash | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
}
$objhash.PSObject.Properties | ForEach-Object {
    $exchash | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
}

$simhash = [PSCustomObject]@{}
$exchash.PSObject.Properties | ForEach-Object {
    $simhash | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value.Value
}

$fext = [IO.Path]::GetExtension($OutputFilePath)
$pext = '(\.[^.]*)$'

[string]$simpleOutputJsonPath = $null
[string]$outputVdfPath = $null
[string]$simOutputVdfPath = $null

if ([string]::IsNullOrWhiteSpace($fext)) {
    $simpleOutputJsonPath = "$($OutputFilePath)~s0"
    $outputVdfPath = "$($OutputFilePath).kv"
    $simpleOutputVdfPath = "$($OutputFilePath)~s0.kv"
} else {
    $simpleOutputJsonPath = $OutputFilePath -Replace $pext, "~s0$($fext)"
    $outputVdfPath = [IO.Path]::ChangeExtension($OutputFilePath, '.kv')
    $simpleOutputVdfPath = $OutputFilePath -Replace $pext, '~s0.kv'
}

$exchash | ConvertTo-Json -Compress `
    | Set-Content -LiteralPath $OutputFilePath -Encoding UTF8 -Force

$simhash | ConvertTo-Json -Compress `
    | Set-Content -LiteralPath $simpleOutputJsonPath -Encoding UTF8 -Force

$exchash | ConvertTo-Vdf `
    | Set-Content -LiteralPath $outputVdfPath -Encoding UTF8 -Force

$simhash | ConvertTo-VdfS0 `
    | Set-Content -LiteralPath $simpleOutputVdfPath -Encoding UTF8 -Force

$exchash.PSObject.Properties.Name | Set-Content -LiteralPath $ExcludeFilePath -Encoding UTF8 -Force

$PSStyle.Progress.Style = $DefaultProgressStyle
$PSStyle.Progress.View = $DefaultProgressView
