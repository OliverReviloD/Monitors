#
#   https://github.com/timvideos/edid.tv/blob/master/edid_parser/edid_parser.py
#
# getting EDID data from the plug & play api.
# Get-PnpDevice -Class "Monitor" -Status "OK" | ForEach-Object { $regfile=$([Environment]::GetFolderPath('Desktop') + "\" + $($_.Name) + '.reg'); Write-Host -NoNewline "Exporting $($regfile) : "; reg.exe export "$('HKLM\SYSTEM\CurrentControlSet\Enum\' + $($_.InstanceId) + '\Device Parameters')" "$regfile" /y}
# Get-PnpDevice -Class "Monitor" -Status "OK" 


# 
# https://www.extron.com/article/uedid
<#
    Address	Data	General Description
    (Decimal)		
    0-7	            Header	Constant fixed pattern

    Vendor/Product Identification Block – The first bytes identify the display manufacturer and product, including serial number and date of manufacture.
    8-9	            Manufacturer ID	
    10-11	        Product ID Code	
    12-15	        Serial Number	
    16-17	        Manufacture Date	

    EDID Structure Version & Revision – The next two bytes identify the version and revision of the EDID data within the structure.
         EDID versions 1.3 and higher allow for additional 128-byte blocks of data to describe increased capabilities.
    18	            EDID Version 
    19	            EDID Revision 

    Basic Display Parameters/Features – The next five bytes define characteristics such as whether the display accepts analog or digital inputs, sync types, maximum horizontal and vertical size of the display, gamma transfer characteristics, power management capabilities, color space, and default video timing.
    20	            Video Input Type	
    21	            Horizontal Size (cm)	input type (analog or digital),
    22	            Vertical Size (cm)	    display size, power management,
    23	            Display Gamma	        sync, color space, and timing capabilities and preferences are reported here.
    24	            Supported Features	

    Color Characteristics – The next 10 bytes define the RGB color space conversion technique to be used by the display.
    25-34	        Color Characteristics	       Color space definition
    35-36	        Established Supported Timings	
    37	            Manufacturer's Reserved Timing	
    38-53	        EDID Standard Timings          Supported	Timing information for all resolutions supported by the display are reported here
    54-71	        Detailed Timing Descriptor Block 1	
    72-89	        Detailed Timing Descriptor Block 2	
    90-107	        Detailed Timing Descriptor Block 3	
    108-125	        Detailed Timing Descriptor Block 4	
    126	            Extension Flag	Number of (optional) 128-byte extension blocks to follow, EDID versions 1.3 and higher -> describe increased capabilities.
    127	           Checksum	
#>


if ( 1 -eq 2 -or $InstanceID -eq $Null) 
    {
    $InstanceID = (Get-PnpDevice -Class "Monitor" -Status "OK" | Where { $_.FriendlyName -ne 'Integrated Monitor'  } ).InstanceId
    Write-Host "Get-PnpDevice( Class = Monitor) InstanceID = '$InstanceID'"
    $RegKey = 'HKLM:\SYSTEM\CurrentControlSet\Enum\' + $($InstanceID) + '\Device Parameters'
    [byte[]]$ByteArrayEDID = Get-ItemPropertyValue -Path $RegKey -Name EDID
    [Array]$HexArrayEDID  = ($ByteArrayEDID | ForEach-Object { '{0:X2}' -f $_ }) 
    }

if ( 1 -eq 2) 
    {
    $InstanceID = (Get-PnpDevice -Class "Monitor" -Status "OK" | Where { $_.FriendlyName -eq 'Integrated Monitor'  } ).InstanceId
    Write-Host "Get-PnpDevice( Class = Monitor) InstanceID = '$InstanceID'"
    $RegKey = 'HKLM:\SYSTEM\CurrentControlSet\Enum\' + $($InstanceID) + '\Device Parameters'
    [byte[]]$ByteArrayEDID = Get-ItemPropertyValue -Path $RegKey -Name EDID
    [Array]$HexArrayEDID  = ($ByteArrayEDID | ForEach-Object { '{0:X2}' -f $_ }) 
    }

Write-Host "Get-PnpDevice( Class = Monitor) InstanceID = '$InstanceID'"
Write-Host "Get-ItemPropertyValue( RegKeyName = EDID) BYTE = '$($ByteArrayEDID -join ' ') '"
Write-Host "Get-ItemPropertyValue( RegKeyName = EDID) HEX  = '$($HexArrayEDID -join ' ') '"


if ( $ByteArrayEDID.count -lt 128)            {  Write-error "EDID parsing - Error  - Binary stream is smaller than 128 bytes." }
if ( ($($ByteArrayEDID.count) % 128) -ne 0 )  {  Write-error "EDID parsing - Error  - Binary stream is not a multiple of 128 bytes."}
else                                          {  Write-host  "EDID parsing - Binary stream is a multiple of 128 bytes." -ForegroundColor green}

[String]$EDIDHeaderByte = [String]::Join(' ',$ByteArrayEDID, 0,8)
[String]$EDIDHeaderHex  = [String]::Join(' ',$HexArrayEDID , 0,8)
Write-Host "Bytes [  0 -   7]  -> EDIDHeader (byte) = '$EDIDHeaderByte'"
Write-Host "Bytes [  0 -   7]  -> EDIDHeader (hex)  = '$EDIDHeaderHex'"
# if ( $EDIDHeaderByte -ne "0x00, 0xff, 0xff, 0xff, 0xff, 0xff,0xff, 0x00")   {  Write-error " EDIDParsingError  - Binary stream is not an EDID hex stream."}
if ( $EDIDHeaderByte   -ne "0 255 255 255 255 255 255 0")                     {  Write-error " EDIDParsingError  - Binary stream is not an EDID hex stream."}

################################
<#
    ID Manufacturer Name    = edid[ 8 - 9 ]

    Bits 14–10	First letter of manufacturer  ID (byte 8, bits 6–2)
    Bits 9–5	Second letter of manufacturer ID (byte 8, bit 1 through byte 9 bit 5)
    Bits 4–0	Third letter of manufacturer  ID (byte 9, bits 4–0)

    [Convert]::ToString(192,2)   -> 11000000
       
    big-endian 16-bit value - made up of three 5-bit letters: 
                            00001, A;                       1 * 1
                            00010, B;                      
                            00011, C;   
                            00100, D;   
                            …; 
                            01001, I;
                            …; 
                            01101, M;
                            …; 
                            11010, Z        0*1 + 1*2 + 0*4 + 1*8 + 1*16 = 26
                        
                        E.g., (hex)24 (hex)4d  =>  0 01001 00010 01101   => "IBM".
                                         

    $asDecimal = [System.Convert]::ToInt64("24", 16)   #  -> 36   # Byte[8] -  'INT:36'  # $([Convert]::ToString(36,2)).PadLeft(8,"0")   -> BitString8='00100100'
    $asDecimal = [System.Convert]::ToInt64("4d", 16)   #  -> 77   # Byte[9] -  'INT:77'  # $([Convert]::ToString(77,2)).PadLeft(8,"0")   -> BitString9='01001101'

    $BitString8   = $([Convert]::ToString(36,2)).PadLeft(8,"0")
    $BitString9   = $([Convert]::ToString(77,2)).PadLeft(8,"0")
    $BitStringAll = "$BitString8" + "$BitString9"   # 0 01001 00010 01101
    $FirstLetter  = $BitStringAll.Substring(1,5)    # 01001
    $SecondLetter = $BitStringAll.Substring(6,5)    # 00010
    $ThirdLetter  = $BitStringAll.Substring(11,5)   # 01101
    $ArrLetters = @( $FirstLetter , $SecondLetter, $ThirdLetter )
    ForEach($SearchLetter in $ArrLetters )
        {
        $SearchLetter
        for ($test = 1; $test -lt 27; $test++)
            {
            [char]$Letter = [char](65 -1 + $test )
            $BitString = $([Convert]::ToString($test,2)).PadLeft(5,"0") 
            if ( $BitString -eq $SearchLetter )   {         Write-Host "$Letter    $Test   $BitString" }
            }
        }

#>
$IndexStart = 8   # and 9    # Manufacturer Name  - Part 1    : 
$LoopCount  = 1
[String]$Value      = $Null
$IBMTEST = $false
$EndIndex = $IndexStart
if ( $IBMTEST )
    {
    [byte[]]$ByteArrayEDID_Debug      = $ByteArrayEDID
    $ByteArrayEDID_Debug[$IndexStart] = 36
    [Array]$HexArrayEDID_Debug   = ($ByteArrayEDID | ForEach-Object { '{0:X2}' -f $_ }) 
   # Write-Host "Pos: $IndexStart -  HEX: $($HexArrayEDID_Debug[$IndexStart])  -  $($ByteArrayEDID_Debug[$IndexStart])  - $([char]$ByteArrayEDID_Debug[$IndexStart])"
    $Value = $ByteArrayEDID_Debug[$IndexStart]
    }
else
    {
  #  Write-Host "Pos: $IndexStart -  HEX: $($HexArrayEDID[$IndexStart])  -  $($ByteArrayEDID[$IndexStart])  - $([char]$ByteArrayEDID[$IndexStart])"
    $Value = $ByteArrayEDID[$IndexStart]
    }
Write-Host "Bytes [  $IndexStart -   $EndIndex]  -> 'Manufacturer ID' = " -NoNewline
if ( $Value -ne $Null   ) { $Value = $Value.TRim() }

[String]$BitString8  = $([Convert]::ToString($Value,2)).PadLeft(8,"0")
Write-Host "'INT:$Value'  -> BitString8='$BitString8'" 


$IndexStart =  9    # Manufacturer Name  - Part 2 : 
$LoopCount  = 1
[String]$Value      = $Null
$EndIndex = $IndexStart 
if ( $IBMTEST )
    {
    [byte[]]$ByteArrayEDID_Debug      = $ByteArrayEDID
    $ByteArrayEDID_Debug[$IndexStart] = 77
    [Array]$HexArrayEDID_Debug   = ($ByteArrayEDID | ForEach-Object { '{0:X2}' -f $_ }) 
  #  Write-Host "Pos: $IndexStart -  HEX: $($HexArrayEDID_Debug[$IndexStart])  -  $($ByteArrayEDID_Debug[$IndexStart])  - $([char]$ByteArrayEDID_Debug[$IndexStart])"
    $Value = $ByteArrayEDID_Debug[$IndexStart]
    }
else
    {
   # Write-Host "Pos: $IndexStart -  HEX: $($HexArrayEDID[$IndexStart])  -  $($ByteArrayEDID[$IndexStart])  - $([char]$ByteArrayEDID[$IndexStart])"
    $Value = $ByteArrayEDID[$IndexStart]
    }
Write-Host "Bytes [  $IndexStart -   $EndIndex]  -> 'Manufacturer ID' = " -NoNewline
if ( $Value -ne $Null   ) { $Value = $Value.TRim() }

[String]$BitString9  = $([Convert]::ToString($Value,2)).PadLeft(8,"0")
Write-Host "'INT:$Value'  -> BitString9='$BitString9'" 


$BitStringAppended = "$BitString8" + "$BitString9"   # 0 01001 00010 01101    # IBM
Write-Host "--- 'Byte[8] and Byte[9]'  -> BitStringAppended ='$BitStringAppended'" 
$FirstLetter  = $BitStringAppended.Substring(1,5)    # 01001
$SecondLetter = $BitStringAppended.Substring(6,5)    # 00010
$ThirdLetter  = $BitStringAppended.Substring(11,5)   # 01101
$ArrLetters = @( $FirstLetter , $SecondLetter, $ThirdLetter )
$BitStringByLetters = "$($BitString8.Substring(0,1)) $FirstLetter $SecondLetter $ThirdLetter"
Write-Host "--- 'Byte[8] and Byte[9]'  -> BitStringByLetters='$BitStringByLetters'" 

$ManufacturerID = $Null
ForEach($SearchLetter in $ArrLetters )
    {
    # $SearchLetter
    for ($test = 1; $test -lt 27; $test++)
        {
        [char]$Letter = [char](65 -1 + $test )
        $BitString = $([Convert]::ToString($test,2)).PadLeft(5,"0") 
        if ( $BitString -eq $SearchLetter )   {         Write-Host "--- [BIT]$BitString => [INT]$Test =  -> $Letter  "; $ManufacturerID =  $ManufacturerID + $Letter; break }
        }
    }

Function ConvertTo-Manufacturer ($Code) {
    #
    #  function copied from 
    #
    #  https://help.pdq.com/hc/en-us/community/posts/13637242918171-Powershell-Scanner-Script-to-gather-info-on-attached-monitors
    #

    $Output = ''
    # initialise monitor manufacturers
    $Manufacturer = @(
        [pscustomobject]@{'Monitor Manufacturer Code'='DEL';'Monitor Manufacturer'='Dell Computer Corp.'}
        [pscustomobject]@{'Monitor Manufacturer Code'='SNY';'Monitor Manufacturer'='Sony Corporation'}
        #
        # and many more
        #
        )
        $Output = $Manufacturer | Where-Object {$_.'Monitor Manufacturer Code' -eq $Code} | select -ExpandProperty 'Monitor Manufacturer'
    If (!$Output) {Return $Code}
    else {Return $Output}
    }

Write-Host "Bytes [  $($IndexStart-1) -   $EndIndex]  -> 'Manufacturer ID' = '$ManufacturerID' = " -NoNewline
Write-Host (ConvertTo-Manufacturer -code $ManufacturerID)




################################
$IndexStart = 10   # and 11    # ProductCode      : 
$LoopCount  = 1
[String]$Value      = $Null
$EndIndex = $IndexStart + $LoopCount
Write-Host "Bytes [ $IndexStart -  $EndIndex]  -> 'ProductCode' = '" -NoNewline
$Value = "$($HexArrayEDID[$IndexStart+ $LoopCount])$($HexArrayEDID[$IndexStart])"
if ( $Value -ne $Null   ) { $Value = $Value.TRim() }
Write-Host "$Value'" 


################################
$IndexStart = 16       # WeekOfMfg          : 8
$LoopCount  = 0
[String]$Value      = $Null
$EndIndex = $IndexStart + $LoopCount
Write-Host "Bytes [ $IndexStart -  $EndIndex]  -> 'WeekOfMfg' = '" -NoNewline
$Value =  $ByteArrayEDID[$IndexStart]
Write-Host "$Value'" 


################################
$IndexStart = 17       # YearOfMfg          : 2020
$LoopCount  = 0
[String]$Value      = $Null
$EndIndex = $IndexStart + $LoopCount
Write-Host "Bytes [ $IndexStart -  $EndIndex]  -> 'YearOfMfg' = '" -NoNewline
$Value = 1990 + [char]$ByteArrayEDID[$IndexStart]
Write-Host "$Value'" 



<#       EDID Structure Version & Revision – The next two bytes identify the version and revision of the EDID data within the structure.
         EDID versions 1.3 and higher allow for additional 128-byte blocks of data to describe increased capabilities.
    18	            EDID Version 
    19	            EDID Revision 
#>
################################
$IndexStart = 18   # and 19    # EDID Version.Revision       : 1.3
$LoopCount  = 1
[String]$Value      = $Null
$EndIndex = $IndexStart + $LoopCount
Write-Host "Bytes [ $IndexStart -  $EndIndex]  -> 'EDID Version.Revision' = '" -NoNewline
$Value = "$($ByteArrayEDID[$IndexStart]).$($ByteArrayEDID[$IndexStart + $LoopCount])"
if ( $Value -ne $Null   ) { $Value = $Value.TRim() }
Write-Host "$Value'" 


################################
# Basic_display_parameters  = edid[20:25]   -  Video Input Type = 128 = DisplayPort ,   WidthCm = 80,   HeightCm = 33,  Size_Inch - diagonal,  Supported Features
################################
$IndexStart = 20       # Video Input Type    hex: 80   dec: 128
$LoopCount  = 0
[String]$Value      = $Null
$EndIndex = $IndexStart + $LoopCount
Write-Host "Bytes [ $IndexStart -  $EndIndex]  -> 'Video Input Type'  = '" -NoNewline
# Write-Host "Pos: $IndexStart -  HEX: $($HexArrayEDID[$IndexStart])  -  $($ByteArrayEDID[$IndexStart])  - $([char]$ByteArrayEDID[$IndexStart])"
$Value = $ByteArrayEDID[$IndexStart]
Write-Host "$Value'   ( 128 = DisplayPort?)"    


<#

    copied somewhere from the internet     - not verified or tested

    Dell 2007FP monitors -   41cmx31cm   ->         EDID 21-22 (0x29 0x1F)
                            367mmx275mm  ->         EDID 66-68 (0x6F 0x13 0x11)

    028: WidthCm = EDIDdata[21];
    029: HeightCm = EDIDdata[22];

    ->Change Code [CM -> MM]
            int a = EDIDdata[68];
            int high,low,hor,ver;
            high = a/16;
            low = a%16;
            hor = high*256 + EDIDdata[66];
            ver = low*256 + EDIDdata[67];


    WidthMm = ((EDIDdata[68] & 0xF0) << 4) + EDIDdata[66];
    HeightMm = ((EDIDdata[68] & 0x0F) << 8) + EDIDdata[67];
#>

################################
$IndexStart = 21       # WidthCm    80
$LoopCount  = 0
[String]$Value      = $Null
$EndIndex = $IndexStart + $LoopCount
Write-Host "Bytes [ $IndexStart -  $EndIndex]  -> 'Width_Cm'  = '" -NoNewline
$Value = $ByteArrayEDID[$IndexStart]
Write-Host "$Value'"
$SizeWidth_cm = $Value    


################################
$IndexStart = 22       # HeightCm    33
$LoopCount  = 0
[String]$Value      = $Null
$EndIndex = $IndexStart + $LoopCount
Write-Host "Bytes [ $IndexStart -  $EndIndex]  -> 'Height_Cm' = '" -NoNewline
$Value = $ByteArrayEDID[$IndexStart]
Write-Host "$Value'"    
$SizeHeight_cm = $Value  


################################
Write-Host "Bytes [ 21 -  22]  -> 'Size_Inch - diagonal' = '" -NoNewline
# Pythagoras    A*A + B*B = C*C
$AA = [System.Math]::Pow($SizeWidth_cm  , 2) 
$BB = [System.Math]::Pow($SizeHeight_cm , 2)
$Sizediagonal_inch = ([System.Math]::Round( ([System.Math]::Sqrt( $AA  + $BB ) / 2.54)  , 0))
Write-Host "$Sizediagonal_inch'"    


################################
#  https://en.wikipedia.org/wiki/Extended_Display_Identification_Data
$IndexStart = 24   # and 11    # Supported Features      : 
$LoopCount  = 0
[String]$Value      = $Null
$EndIndex = $IndexStart + $LoopCount
# Write-Host "Pos: $IndexStart -  HEX: $($HexArrayEDID[$IndexStart])  -  $($ByteArrayEDID[$IndexStart])  - $([char]$ByteArrayEDID[$IndexStart])"
Write-Host "Bytes [ $IndexStart -  $EndIndex]  -> 'Supported Features' = " -NoNewline
$Value = $ByteArrayEDID[$IndexStart]
if ( $Value -ne $Null   ) { $Value = $Value.TRim() }
[String]$BitString24  = $([Convert]::ToString($Value,2)).PadLeft(8,"0")
Write-Host "'INT:$Value'  -> BitString24='$BitString24'" 


     
     # 'Chromaticity'            = edid[25:35]
     # 'Established_Timings'     = edid[35:38]
     # 'Standard_Timings'        = edid[38:54]
     # 'Descriptors'             = edid[54:126]
     # 'Extension_Flag'          = edid[126]

<#
    
    Only for debugging  and development

    ################################
    cls
    $IndexStart = 38
    $LoopCount  = 18
    [String]$Value      = $Null
    Write-Host "Start search at Byte[$IndexStart] for next $LoopCount bytes "
    for ($i= $IndexStart; $i  -lt ($IndexStart  + $LoopCount  ); $i++)
        {
        Write-Host "Pos: $i -  HEX: $($HexArrayEDID[$i])  -  $($ByteArrayEDID[$i])  - $([char]$ByteArrayEDID[$i])"
        $Value = $Value  + "" + [char]$ByteArrayEDID[$i]
        Write-Host 
        }
    if ( $Value -ne $Null   ) { $Value = $Value.TRim() }
    Write-Host $Value 



#>

################################
$IndexStart = 77       # SerialNumber       : JP436T2
$LoopCount  = 8
[String]$Value      = $Null
$EndIndex = $IndexStart + $LoopCount
Write-Host "Bytes [ $IndexStart -  $EndIndex]  -> 'SerialNumber' = '" -NoNewline
# Write-Host "Start search at Byte[$IndexStart] for next $LoopCount bytes "
for ($i= $IndexStart; $i  -lt ($IndexStart  + $LoopCount  ); $i++)
    {
   # Write-Host "Pos: $i -  HEX: $($HexArrayEDID[$i])  -  $($ByteArrayEDID[$i])  - $([char]$ByteArrayEDID[$i])"
    $Value = $Value  + "" + [char]$ByteArrayEDID[$i]
    }
if ( $Value -ne $Null   ) { $Value = $Value.TRim() }
Write-Host "$Value'" 


################################
$IndexStart = 85       # unknown
$LoopCount  = 5
[String]$Value      = $Null
$EndIndex = $IndexStart + $LoopCount
Write-Host "Bytes [ $IndexStart -  $EndIndex]  -> 'unknown' = '" -NoNewline
for ($i= $IndexStart; $i  -lt ($IndexStart  + $LoopCount  ); $i++)
    {
  #  Write-Host "Pos: $i -  HEX: $($HexArrayEDID[$i])  -  $($ByteArrayEDID[$i])  - $([char]$ByteArrayEDID[$i])"
    $Value = $Value  + "" + [char]$ByteArrayEDID[$i]
   # Write-Host 
    }
if ( $Value -ne $Null   ) { $Value = $Value.TRim() }
Write-Host "$Value'    value length=$($Value.Length) " 


################################
#
# https://stackoverflow.com/questions/10255737/how-to-read-the-model-of-monitor-from-the-edid
#
# 54-71, 72-89, 90-107, and 108-125
# Check at offsets 54, 72, 90, and 108 for the sequence 00 00 00 FC; if you find a match, the monitor name is the next 12 bytes.

# Write-Host "`r`nSearching for 'Manufacturer Model' in EDID"
$EDIDMonitorNameString = $Null                #   => DELL U3419W 
$ArrIndexNumbers = @( 54, 72, 90, 108 )
$LoopCount  = 18
ForEach ( $IndexStart in $ArrIndexNumbers )
    {
  #  Write-Host "Start search at Byte[$IndexStart] - 18 characters long for Strings '00 00 00 FC' or  '00 00 00 FE'    " -NoNewline
    [String]$EDIDMonitorNameHex  = [String]::Join(' ',$HexArrayEDID , $IndexStart ,18)
 #   Write-host $EDIDMonitorNameHex
    if( $EDIDMonitorNameHex.StartsWith( "00 00 00 FC" ) -or $EDIDMonitorNameHex.StartsWith( "00 00 00 FE" ) )
        {
        $EndIndex = $IndexStart + $LoopCount
        Write-Host "Bytes [ $IndexStart - $EndIndex]  -> 'Manufacturer Model' = '" -NoNewline
        # Write-Host "StartsWith - $EDIDMonitorNameHex"
        for ($i=$IndexStart + 5 ; $i -le ($IndexStart  + $LoopCount); $i++)
            {
            if ( $ByteArrayEDID[$i] -ne 10 -and $ByteArrayEDID[$i] -ne 0 )     #  10 = `r`n
                {
               # Write-Host "Pos: $i -  HEX: $($HexArrayEDID[$i])  -  $($ByteArrayEDID[$i])  - $([char]$ByteArrayEDID[$i])"
                $EDIDMonitorNameString = $EDIDMonitorNameString  + [char]$ByteArrayEDID[$i]
                }
            }
        if ( $EDIDMonitorNameString -ne $Null   ) { $EDIDMonitorNameString = $EDIDMonitorNameString.TRim() }
        Write-Host "$EDIDMonitorNameString'"
        }
    }
