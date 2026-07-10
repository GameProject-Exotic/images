# Exotic / Images
Mostly images for Trikz, Surf, and Bhop maps. And other visual assets we use..

## Extract-ImageColor Script
[Extract-ImageColor](./Extract-ImageColor.ps1) is a PowerSheel 7 script (enfores through `#Requires -Version 7`). It exists along side with its [helper-module](./Extract-ImageColor.psm1). It depends on [Image Magick](https://imagemagick.org) to get image histograms. The only thing it does, it iterates through images in a directory and then parses a histogram of every image, and writes it down to a *.kv ([Valve Data Format](https://developer.valvesoftware.com/wiki/VDF)) file.

### Parameters
| Name | Aliases | Default | Description | Behaviour |
|:-|:-|:-|:-|:-|
| SourceDirectoryPath | 1. SourceDirectory<br>2. SourceDir<br>3. SrcDir<br>4. Source<br>5. Src | /maps/main/ | Relative or absolute path to a directory where all needed images reside. | Only checked for existence. |
| OutputFilePath | 1. OutputFile<br>2. OutFile<br>3. Output<br>4. Out | /maps/colors.kv | Relative or absolute path to a file to which write calculated colors of images from \`SourceDirectoryPath\`. | Created if it does not exists, or overwritten if it does exists. |
| ExcludeFilePath | 1. ExcludeFile<br>2. Exclude | /maps/excludes.txt | Text file where every line is a \`BaseName\` of an image which needed to be excluded. | Empty list is used if that file does not exists. |
| SampleColorCount | SampleCount | 4 | Number of colors of a single image to use for the image color calculation. | Just passed to Image Magick as a \`-colors\` parameter. |

### Usage
```
Extract-ImageColor.ps1 [[-SourceDirectoryPath] <string>] [[-OutputFilePath] <string>] [[-ExcludeFilePath] <string>] [[-SampleColorCount] <int>]
```
#### Output
```
No cat~ images! Only boring maps of fictional worlds.. [Squashing this dummy trikz_0effort_fix..                     ]
```

### Format
We use *.kv ([Valve Data Format](https://developer.valvesoftware.com/wiki/VDF)) files in our SourceMod plugins and currently have no need for other formats.

#### General
[/maps/colors.kv](./maps/colors.kv)
```
"Map Image Colors"
{
    "map_name"
    {
        "Value" "@int"
        "Hex" "@string[6]"
        "Red" "@float[0-255]"
        "Green" "@float[0-255]"
        "Blue" "@float[0-255]"
        "Red Hex" "@string[2]"
        "Green Hex" "@string[2]"
        "Blue Hex" "@string[2]"
        "Hue" "@float[0-360]"
        "Saturation" "@float[0-1]"
        "Brightness" "@float[0-1]"
    }
}
```

#### Simple~0
[/maps/colors~s0.kv](./maps/colors~s0.kv)
```
"Map Image Colors"
{
    "map_name" "@int"
}
```

#### Simple~1
[/maps/colors~s1.kv](./maps/colors~s1.kv)
```
"Map Image Colors"
{
    "map_name"
    {
        "Value" "@int"
    }
}
```

## License
Licensed under the [GPL-3.0 license](./COPYING). Currently, applied only to [Extract-ImageColor.ps1](./Extract-ImageColor.ps1) and [Extract-ImageColor.psm1](./Extract-ImageColor.psm1) files.
