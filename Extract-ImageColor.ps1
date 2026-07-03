param(
    [Alias('SourceDirectory', 'SrcDir', 'Source', 'Src')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$SourceDirectoryPath = [NullString]::Value,

    [Alias('OutputFile', 'OutFile', 'Output', 'Out')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$OutputFilePath = [NullString]::Value,

    [Alias('ExcludeFile', 'Exclude')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$ExcludeFilePath = [NullString]::Value,

    [Alias('SampleCount')]
    [AllowNull()]
    [Nullable[int]]$SampleColorCount = $null
)

#Requires -Version 7

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

[object[]]$includes = (Get-ChildItem -LiteralPath $SourceDirectoryPath -Filter '*.jpg' -File -Force)
if ($excludes.Count -Ne 0) {
    $includes = $includes.Where({ $_.BaseName -NotIn $excludes })
}
if ($includes.Count -Eq 0) {
    Write-Warning 'He~y.. You forgot to put somw images! No~o, not the cat~ ones..'
    return
}

$PSStyle.Progress.Style = $ProgressStyle
$PSStyle.Progress.View = $ProgressView

$kv = [Text.StringBuilder]::new()
Write-SectionStart $kv $KeyValueColorRootSectionName

[int]$progress = 0
$includes | ForEach-Object {
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
                Count = $count
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
        $red = ($colors | ForEach-Object -PipelineVariable x { $_.Red * $_.Weight } | Measure-Object -Sum).Sum / $weight
        $green = ($colors | ForEach-Object { $_.Green * $_.Weight } | Measure-Object -Sum).Sum / $weight
        $blue = ($colors | ForEach-Object { $_.Blue * $_.Weight } | Measure-Object -Sum).Sum / $weight
    }

    [string[]]$hvals = Convert-ToHex $red $green $blue

    [string]$hred = $hvals[0]
    [string]$hgreen = $hvals[1]
    [string]$hblue = $hvals[2]

    [string]$hex = [string]::Join('', $hvals)

    [string[]]$hsb = Convert-ToHsb $red $green $blue
    [float]$hue = $hsb[0]
    [float]$saturation = $hsb[1]
    [float]$brightness = $hsb[2]

    [int]$value = [Convert]::ToInt32($hex, 16)

    Write-SectionStart $kv $_.BaseName
    # {
        Write-KeyValue $kv $KeyValueColorValueKey $value
        Write-KeyValue $kv $KeyValueColorHexKey $hex
        Write-KeyValue $kv $KeyValueColorRedComponentKey $red
        Write-KeyValue $kv $KeyValueColorGreenComponentKey $green
        Write-KeyValue $kv $KeyValueColorBlueComponentKey $blue
        Write-KeyValue $kv $KeyValueColorRedHexComponentKey $hred
        Write-KeyValue $kv $KeyValueColorGreenHexComponentKey $hgreen
        Write-KeyValue $kv $KeyValueColorBlueHexComponentKey $hblue
        Write-KeyValue $kv $KeyValueColorHueComponentKey $hue
        Write-KeyValue $kv $KeyValueColorSaturationComponentKey $saturation
        Write-KeyValue $kv $KeyValueColorBrightnessComponentKey $brightness
    # }
    Write-SectionClose $kv

    ++$progress
}

Write-SectionClose $kv
[void]$kv.Append("`n")

$kv.ToString() | Set-Content -LiteralPath $OutputFilePath -Encoding UTF8 -NoNewLine -Force
"$([string]::Join("`n", ($includes | Select-Object -ExpandProperty BaseName)))`n" | Set-Content -LiteralPath $ExcludeFilePath -Encoding UTF8 -NoNewLine -Force

$PSStyle.Progress.Style = $DefaultProgressStyle
$PSStyle.Progress.View = $DefaultProgressView
