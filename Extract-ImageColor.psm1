Set-StrictMode -Version 3.0

function New-Constant {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        $Value
    )

    New-Variable -Scope Script -Option Constant -Name $Name -Value $Value
}

function Get-NameOf {
    param(
        [Parameter(Mandatory)]
        [ScriptBlock]$Expression
    )

    $element = $Expression.Ast.EndBlock.Statements[0].PipelineElements[0]
    $elementPath = $element.Expression.VariablePath.UserPath
    if (-Not $elementPath) {
        throw 'Could not get the name of the provided expression by assuming it was a variable!'
    }

    return $elementPath
}

function Get-InvalidDirectoryPathErrorMessage {
    param(
        [Parameter(Mandatory)]
        [string]$ParamName
    )

    return "The specified `$$($ParamName) parameter represents an invalid directory path. It could be that the path does not exists, or it is not a directory!"
}

function Get-InvalidFilePathErrorMessage {
    param(
        [Parameter(Mandatory)]
        [string]$ParamName
    )

    return "The specified `$$($ParamName) parameter represents an invalid file path. It could be that the path does not exists, or it is not a file!"
}

function Test-SourceDirectoryPath {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    return -Not [string]::IsNullOrWhiteSpace($Value)
}

function Test-OutputFilePath {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    return -Not [string]::IsNullOrWhiteSpace($Value)
}

function Test-ExcludeFilePath {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    return -Not [string]::IsNullOrWhiteSpace($Value)
}

function Test-SampleColorCount {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [Nullable[int]]$Value
    )

    return -Not (($Value -Eq $null) -Or ($Value -Le 0))
}

function Convert-ToHex {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [Nullable[float]]$Red,

        [Parameter(Mandatory)]
        [AllowNull()]
        [Nullable[float]]$Green,

        [Parameter(Mandatory)]
        [AllowNull()]
        [Nullable[float]]$Blue
    )

    function Normalize-ColorComponent {
        param(
            [Parameter(Mandatory)]
            [AllowNull()]
            [Nullable[float]]$Value
        )

        if ($Value -Eq $null) {
            return 0
        }

        return [int][Math]::Round([Math]::Clamp([Math]::Abs($Value), 0, 255))
    }

    function Format-ColorComponent {
        param(
            [Parameter(Mandatory)]
            [AllowNull()]
            [Nullable[int]]$Value
        )

        if ($Value -Eq $null) {
            $Value = 0
        }

        return '{0:X2}' -F $Value
    }

    return (Format-ColorComponent (Normalize-ColorComponent $Red)), `
        (Format-ColorComponent (Normalize-ColorComponent $Green)), `
        (Format-ColorComponent (Normalize-ColorComponent $Blue))
}

function Convert-ToHsb {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [Nullable[float]]$Red,

        [Parameter(Mandatory)]
        [AllowNull()]
        [Nullable[float]]$Green,

        [Parameter(Mandatory)]
        [AllowNull()]
        [Nullable[float]]$Blue
    )

    function Normalize-ColorComponent {
        param(
            [Parameter(Mandatory)]
            [AllowNull()]
            [Nullable[float]]$Value
        )

        if ($Value -Eq $null) {
            return 0.f
        }

        return [Math]::Clamp([Math]::Abs($Value), 0, 255) / 255
    }

    $Red = Normalize-ColorComponent $Red
    $Green = Normalize-ColorComponent $Green
    $Blue = Normalize-ColorComponent $Blue

    [object]$mea = $Red, $Green, $Blue | Measure-Object -Minimum -Maximum

    [float]$min = $mea.Minimum
    [float]$max = $mea.Maximum
    [float]$delta = $max - $min

    [float]$h = 0
    [float]$s = 0
    [float]$b = $max

    if (($delta -Lt 0.00001) `
            -Or ($max -Eq 0)) {
        return $h, $s, $b
    }

    $s = $delta / $max
    if ($Red -Eq $max) {
        $h = ($Green - $Blue) / $delta
    } elseif ($Green -Eq $max) {
        $h = 2 + ($Blue - $Red) / $delta
    } else {
        $h = 4 + ($Red - $Green) / $delta
    }

    $h *= 60
    if ($h -Lt 0) {
        $h += 360
    }

    return $h, $s, $b
}

function Write-SectionStart {
    param(
        [Parameter(Mandatory)]
        [Text.StringBuilder]$Builder,

        [Parameter(Mandatory)]
        [string]$Name
    )

    [void]$Builder.Append('"')
    [void]$Builder.Append($Name)
    [void]$Builder.Append('"{')
}

function Write-SectionClose {
    param(
        [Parameter(Mandatory)]
        [Text.StringBuilder]$Builder
    )

    [void]$Builder.Append('}')
}

function Write-KeyValue {
    param(
        [Parameter(Mandatory)]
        [Text.StringBuilder]$Builder,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    [void]$Builder.Append('"')
    [void]$Builder.Append($Key)
    [void]$Builder.Append('"')
    [void]$Builder.Append(' "')
    [void]$Builder.Append($Value)
    [void]$Builder.Append('"')
}


New-Constant -Name 'DefaultSourceDirectoryPath' -Value (Join-Path $PSScriptRoot 'maps' 'main')
New-Constant -Name 'DefaultOutputFilePath' -Value (Join-Path $PSScriptRoot 'maps' 'colors.kv')
New-Constant -Name 'DefaultExcludeFilePath' -Value (Join-Path $PSScriptRoot 'maps' 'excludes.txt')
New-Constant -Name 'DefaultSampleColorCount' -Value 4

New-Constant -Name 'DefaultProgressStyle' -Value $PSStyle.Progress.Style
New-Constant -Name 'DefaultProgressView' -Value $PSStyle.Progress.View

New-Constant -Name 'ProgressStyle' -Value "$([char]0x1b)[38;2;255;199;231m"
New-Constant -Name 'ProgressView' -Value 'Minimal'

New-Constant -Name 'ProgressImageProcessId' -Value 1
New-Constant -Name 'ProgressImageProcessActivity' -Value 'No cat~ images! Only boring maps of fictional worlds..'
New-Constant -Name 'ProgressImageProcessStatus' -Value 'Squashing this dummy {0}..'

New-Constant -Name 'ColorHistogramCountRegexGroup' -Value 'count'
New-Constant -Name 'ColorHistogramRedComponentRegexGroup' -Value 'red'
New-Constant -Name 'ColorHistogramGreenComponentRegexGroup' -Value 'green'
New-Constant -Name 'ColorHistogramBlueComponentRegexGroup' -Value 'blue'
New-Constant -Name 'ColorHistogramHexRegexGroup' -Value 'hex'
New-Constant -Name 'ColorHistogramRedHexComponentRegexGroup' -Value 'hred'
New-Constant -Name 'ColorHistogramGreenHexComponentRegexGroup' -Value 'hgreen'
New-Constant -Name 'ColorHistogramBlueHexComponentRegexGroup' -Value 'hblue'
New-Constant -Name 'ColorHistogramRegex' -Value ([Regex]::new("^\s*(?<$($ColorHistogramCountRegexGroup)>\d+):\s*\(\s*(?<$($ColorHistogramRedComponentRegexGroup)>\d+\.\d+)\s*,\s*(?<$($ColorHistogramGreenComponentRegexGroup)>\d+\.\d+)\s*,\s*(?<$($ColorHistogramBlueComponentRegexGroup)>\d+\.\d+)\s*\)\s*#(?<$($ColorHistogramHexRegexGroup)>(?<$($ColorHistogramRedHexComponentRegexGroup)>[0-9A-Fa-f]{2})(?<$($ColorHistogramGreenHexComponentRegexGroup)>[0-9A-Fa-f]{2})(?<$($ColorHistogramBlueHexComponentRegexGroup)>[0-9A-Fa-f]{2}))\s*srgb\(\s*\d+\.\d+%\s*,\s*\d+\.\d+%\s*,\s*\d+\.\d+%\s*\)\s*$"))

New-Constant -Name 'KeyValueColorRootSectionName' -Value 'Map Image Colors'
New-Constant -Name 'KeyValueColorValueKey' -Value 'Value'
New-Constant -Name 'KeyValueColorHexKey' -Value 'Hex'
New-Constant -Name 'KeyValueColorRedComponentKey' -Value 'Red'
New-Constant -Name 'KeyValueColorGreenComponentKey' -Value 'Green'
New-Constant -Name 'KeyValueColorBlueComponentKey' -Value 'Blue'
New-Constant -Name 'KeyValueColorRedHexComponentKey' -Value 'Red Hex'
New-Constant -Name 'KeyValueColorGreenHexComponentKey' -Value 'Green Hex'
New-Constant -Name 'KeyValueColorBlueHexComponentKey' -Value 'Blue Hex'
New-Constant -Name 'KeyValueColorHueComponentKey' -Value 'Hue'
New-Constant -Name 'KeyValueColorSaturationComponentKey' -Value 'Saturation'
New-Constant -Name 'KeyValueColorBrightnessComponentKey' -Value 'Brightness'


Export-ModuleMember -Function * -Alias * -Variable *
