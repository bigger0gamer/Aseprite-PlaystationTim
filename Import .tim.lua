-- Import .tim by Yuri Bacon
--  An Aseprite lua script to import PlayStation .tim files
--  as an editable sprite, complete with any inluded CLUTs.
--   To export edited sprites back to a .tim, use Export .tim
--   See Export .tim for editing and exporting limitations

-- Version 0.1: WIP is a fuck
--  Currently supports: 4-bit & 8-bit tims. 16-bit and 14-bit forthcoming

-- TODO and known issues
-- transparency is a fuck, you may have to adjust color transparency manual across your color palette

--dbgP(string.format("%02X ", string.byte(timData, v)).." "..string.format("%02X ", string.byte(timData, v+1)))
--no good reason to keep this, but I'm lazy and might want to reference the "print hexidecimal string" formatting

-- if true, the script will print debugging info to the console
-- if false, it won't print anything to console
-- lags the fuck outta the script, so best to keep this off unless you're adding or changing this script
local debugOutput = false

-- "debugPrint", it just prints whatever it's passed if debugOutput is true
function dbgP(consoleText)
  if(debugOutput) then
    print(consoleText)
  end
end




-- create import dialog
local impDlg = Dialog("Import .tim")

-- adds the file open button
impDlg:file
{
  id = "file",
  open = true,
  save = false,
  filetypes = {"tim"}
}

-- Confirm button
impDlg:button
{
  id = "impBtn",
  text = "Import"
}

-- Cancel button
impDlg:button
{
  id = "cancel",
  text = "Cancel"
}

-- show import dialog, script will wait until window disappears
impDlg:show { wait = true }




-- Checking for the user's file
if impDlg.data.impBtn then -- if user pressed cancel, script ends here
  -- Create file handle
  local timFile = io.open(impDlg.data.file, "rb")
  if(timFile == nil) then -- file not found error handling
    app.alert { title="Error!", text="File not found." }
  end
  
  -- Now let's actually load the tim file!
  if(timFile ~= nil) then
    local timData = timFile:read("a")
    timFile:close()
    
    -- if this file doesn't have the magic byte, then it likely isn't a tim file
    if(string.byte(timData, 1) ~= 0x10) then
      app.alert { title="Error!", text="This is not a valid tim file." }
    end
    
    -- and now, conversion time!
    if(string.byte(timData, 1) == 0x10) then
      if(debugOutput) then
        app.alert { title="debugOutput Enabled", text="Printing to console is super slow, so this is gonna take a while..." }
      end
      
      -- Time to read the header
      -- we'll start with the flag saying a CLUT is present
      local hasCLUT = false
      if(string.byte(timData, 5) & 0x8 == 0x8) then
        hasCLUT = true
      end
      dbgP("Has CLUT: " .. tostring(hasCLUT))
      
      -- Last thing we need from the header is the bit depth of the image/color
      local bitsPerPixel = 0
      local header = string.byte(timData, 5) & 0x3 -- using a variable makes it easy to remove the CLUT bit
      
      if(header == 0) then
        bitsPerPixel = 4
      elseif(header == 1) then
        bitsPerPixel = 8
      elseif(header == 2) then
        bitsPerPixel = 16
      elseif(header == 3) then
        bitsPerPixel = 24
      end
      dbgP("Bits Per Pixel: " .. bitsPerPixel)
      
      -- Now it's time to read in the CLUT! If we have one
      local clut = Palette() -- defaults to 256 colors, which happens to match 8-bit tims
      local clutLength = 0 -- we'll need this later to figure out where the image data starts
      local timTable = -- we'll need this to save important framebuffer information to a json,
      {                -- so we can export this information back to a tim in the Export .tim script
        clutBit = hasCLUT,
        bbp = bitsPerPixel,
        clutX = 0,
        clutY = 0,
        clutWidth = 0,
        clutHeight = 0,
        imageX = 0,
        imageY = 0,
        imageWidth = 0,
        imageHeight = 0,
        clutLength = 0,
        imageLength = 0
      }
      
      if(hasCLUT) then
        -- Reading the CLUT length
        timTable.clutLength = string.byte(timData,  9) + 
                             (string.byte(timData, 10) <<  8) + 
                             (string.byte(timData, 11) << 16) + 
                             (string.byte(timData, 12) << 24)
        dbgP("Clut Length: " .. timTable.clutLength)
        
        -- Reading CLUT framebuffer metadata, we'll just be putting it into a JSON
        timTable.clutX = string.byte(timData, 13) + (string.byte(timData, 14) << 8)
        timTable.clutY = string.byte(timData, 15) + (string.byte(timData, 16) << 8)
        timTable.clutWidth = string.byte(timData, 17) + (string.byte(timData, 18) << 8)
        timTable.clutHeight = string.byte(timData, 19) + (string.byte(timData, 20) << 8)
        dbgP("clutX: " .. timTable.clutX)
        dbgP("clutY: " .. timTable.clutY)
        dbgP("clutWidth: " .. timTable.clutWidth)
        dbgP("clutHeight: " .. timTable.clutHeight)
        
        -- now we resize our palette for how many colors we have
        clut:resize(timTable.clutWidth * timTable.clutHeight)
        
        -- we start at 21, as the 21st byte is where the colors of the CLUT start
        -- the end of the clut is the end of the colors
        -- and each color is 2 bytes long
        -- oh, and I said fuck it and made a counter for the number of colors to make
        -- putting those colors into a palette object easier than trying
        -- to math it all from the bytes
        local counter = 0
        dbgP("     ---")
        for b = 21, timTable.clutLength + 8, 2 do
          -- the 2 bytes of the color
          local colorByte = string.byte(timData, b) + (string.byte(timData, b + 1) << 8)
          
          -- So this fucked me up hard, and the only documentation I found confused me to shit
          -- So here is the bit map of the colors, in binary
          -- TBBB BBGG GGGR RRRR
          -- 15                0
          -- Where T = Special Transparency Processing
          -- B = Blue
          -- G = Green
          -- R = Red
          -- and because I couldn't write my and constants in a binary representation
          -- 0x001F  0000 0000 0001 1111
          -- 0x03E0  0000 0011 1110 0000
          -- 0x7C00  0111 1100 0000 0000
          -- 0x8000  1000 0000 0000 0000
          local red = (colorByte & 0x1F) << 3
          local blue = (colorByte & 0x7C00) >> 7
          local green = (colorByte & 0x3E0) >> 2
          local transparencyBit = (((colorByte & 0x8000) / 0x8000) * 255)
          --TODO
          if(b ~= 21) then
            transparencyBit = 255
          end
          
          -- puts the color in our palette
          dbgP("Color " .. counter)
          dbgP("  Red   " .. tostring(red))
          dbgP("  Blue  " .. tostring(blue))
          dbgP("  Green " .. tostring(green))
          dbgP("  Trans " .. tostring(transparencyBit))
          dbgP("     ---")
          clut:setColor(counter, Color{r=red, g=green, b=blue, a=transparencyBit})
          counter = counter + 1
        end
      end
      
      -- whew! Now time for the main event: image data!
      timTable.imageLength = string.byte(timData, timTable.clutLength +  9) + 
                            (string.byte(timData, timTable.clutLength + 10) <<  8) + 
                            (string.byte(timData, timTable.clutLength + 11) << 16) + 
                            (string.byte(timData, timTable.clutLength + 12) << 24)
      dbgP("imageLength: " .. timTable.imageLength)
      
      -- Reading image framebuffer metadata, we'll just be putting it into a json
      timTable.imageX = string.byte(timData, 13 + timTable.clutLength) + (string.byte(timData, 14 + timTable.clutLength) << 8)
      timTable.imageY = string.byte(timData, 15 + timTable.clutLength) + (string.byte(timData, 16 + timTable.clutLength) << 8)
      timTable.imageWidth = string.byte(timData, 17 + timTable.clutLength) + (string.byte(timData, 18 + timTable.clutLength) << 8)
      timTable.imageHeight = string.byte(timData, 19 + timTable.clutLength) + (string.byte(timData, 20 + timTable.clutLength) << 8)
      dbgP("imageX: " .. timTable.imageX)
      dbgP("imageY: " .. timTable.imageY)
      dbgP("imageWidth: " .. timTable.imageWidth)
      dbgP("imageHeight: " .. timTable.imageHeight)
      
      -- Here is the annoying part: We have to read the image data differently for each bit depth
      -- the image height listed in the tim is always correct (TODO actually?) but the width is in
      -- "frame buffer pixels", that is it just lists how many bytes the width takes up, so
      -- I have to divide 16 by bitsPerPixel, and multiply that to get the actual image width
      local sprite = Sprite(timTable.imageWidth * (16 / bitsPerPixel), timTable.imageHeight, ColorMode.INDEXED)
      
      -- Not all tims are color indexed
      if(bitsPerPixel == 16 or bitsPerPixel == 24) then
        sprite.colorMode = ColorMode.RGB
      elseif(bitsPerPixel == 4 or bitsPerPixel == 8) then
        sprite:setPalette(clut)
      end
      
      -- if you see any dbgP() lines commented out, it's because its way too fucking much console output lol
      -- So let's start with 4-bit!
      if(bitsPerPixel == 4) then
        -- our old friend counter will once again help us set the right pixel to the right color
        -- we'll also be needing help keeping track of our xy positions
        local counter = 0
        local x = 0
        local y = 0
        for b = 21 + timTable.clutLength, 8 + timTable.clutLength + timTable.imageLength, 1 do
          -- the colors fucked me up hard, so the cover my bases, I'll just document all the bits
          -- So here is the bit map of the 4-bit indices
          -- 2222 1111
          -- 7       0
          -- Where
          -- 1 = Pixel 1 (of that byte)
          -- 2 = Pixel 2 (of that byte)
          -- and because I couldn't write my and constants in a binary representation
          -- 0x0F  0000 1111
          -- 0xF0  1111 0000
          local color1 =  string.byte(timData, b) & 0x0F
          local color2 = (string.byte(timData, b) & 0xF0) >> 4
          --dbgP("Byte " .. b .. " Color 1: " .. color1)
          --dbgP("Byte " .. b .. " Color 2: " .. color2)
          
          --dbgP("x: " .. x .. " y: " .. y)
          -- We'll just pencil in every color pixel by pixel
          app.useTool
          {
            tool = "pencil",
            color = clut:getColor(color1),
            points = {Point(x, y)} -- TODO brush size 1
          }
          x = x + 1
          if(x >= timTable.imageWidth * (16 / bitsPerPixel)) then
            x = 0
            y = y + 1
          end
          
          --dbgP("x: " .. x .. " y: " .. y)
          -- Because each byte has 2 colors, I was lazy and copy pasted this instead of making some crazy loop
          app.useTool
          {
            tool = "pencil",
            brush = Brush(1),
            color = clut:getColor(color2),
            points = {Point(x, y)}
          }
          x = x + 1
          if(x >= timTable.imageWidth * (16 / bitsPerPixel)) then
            x = 0
            y = y + 1
          end
        end
      
      -- Now 8-bit
      elseif(bitsPerPixel == 8) then
        -- same deal as with 4-bit, get used to this one
        local counter = 0
        local x = 0
        local y = 0
        for b = 21 + timTable.clutLength, 8 + timTable.clutLength + timTable.imageLength, 1 do
          -- lucky for us, 8-bit means 1 color per byte, so this is easy
          local color =  string.byte(timData, b)
          --dbgP("Byte " .. b .. " Color: " .. color) -- this puts so much shit in console it crashes :P, but it works!
          
          -- We'll just pencil in every color pixel by pixel
          app.useTool
          {
            tool = "pencil",
            color = clut:getColor(color),
            points = {Point(x, y)}
          }
          x = x + 1
          if(x >= timTable.imageWidth * (16 / bitsPerPixel)) then
            x = 0
            y = y + 1
          end
        end
      
      -- 16-bit, no more color indexes!
      elseif(bitsPerPixel == 16) then
        --for b = 21 + timTable.clutLength, 8 + timTable.clutLength + timTable.imageLength, 1 do
          dbgP("16-bit tim support coming soon...")
          app.alert { title="!!rrorE", text="16-bit tim support is still forthcoming." }
        --end
      
      -- and finally, 24-bit
      elseif(bitsPerPixel == 24) then
        --for b = 21 + timTable.clutLength, 8 + timTable.clutLength + timTable.imageLength, 1 do
          dbgP("24-bit tim support coming soon...")
          app.alert { title="!!rrorE", text="24-bit tim support is still forthcoming." }
        --end
      end
      
      -- and now, time to save a .json that can hold our important info for exporting!
      local timJson = json.encode(timTable)
      local jsonFile = io.open(impDlg.data.file .. ".aseprite.json", "w")
      jsonFile:write(timJson)
      
      -- finally, let's save our precious palette sprite
      clut:saveAs(impDlg.data.file .. ".ase")
      sprite:saveAs(impDlg.data.file .. ".aseprite")
    end
  end
end
