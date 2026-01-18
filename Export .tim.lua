-- This script sucks, even more than the import
-- I wrote it all angry as fuck and stressed to get shit done as soon as possible
-- dbgP("fuck hibo") indeed!
-- anyways, I can't be bothered to do better, but I added 8bbp support!
-- This pair of scripts is functionally complete ig


-- Export .tim by Yuri Bacon
--  An Aseprite lua script that exports the current sprite / palette to a PlayStation .tim file
--   Intended to export projects originally imported from a .tim with a matching Import .tim script
--   Support for manually specifying options for new / original tims as opposed to edited ones to come later

-- Version 0.1: WIP is a fuck
--  Currently supports: lololololol

--dbgP(string.format("%02X ", string.byte(timData, v)).." "..string.format("%02X ", string.byte(timData, v+1)))
--no good reason to keep this, but I'm lazy and might want to reference the "print hexidecimal string" formatting

-- if true, the script will print debugging info to the console
-- if false, it won't print anything to console
-- Makes script extra laggy, and can cause crashes. Keep off unless you're working on the script
local debugOutput = true

-- "debugPrint", it just prints whatever it's passed if debugOutput is true
function dbgP(consoleText)
  if(debugOutput) then
    print(consoleText)
  end
end




-- create export dialog
local expDlg = Dialog("Export .tim")

-- adds the file open button
expDlg:file
{
  id = "file",
  open = false,
  save = true,
  filetypes = {"tim"}
}

-- Confirm button
expDlg:button
{
  id = "expBtn",
  text = "Export"
}

-- Cancel button
expDlg:button
{
  id = "cancel",
  text = "Cancel"
}

-- show import dialog, script will wait until window disappears
expDlg:show { wait = true }




-- Tim making time!
if expDlg.data.expBtn then -- if user pressed cancel, script ends here
  -- It's not a tim file without a little bit of -~=*@ MAGIC!! @*=~-
  local timString = string.char(0x10, 0, 0, 0)
  
  
  -- now for something a little hard: We need lengths and offsets!!
  -- For now, I'm just going to load the json from Import .tim, and worry about adding manual options later
  local sprite = app.sprite
  local jsonFile = io.open(sprite.filename .. ".json", "rb")
  local timTable = {}
  if(jsonFile == nil) then -- file not found error handling TODO
    app.alert { title="Error!", text="File not found." }
  end
  if(jsonFile ~= nil) then
    local jsonData = jsonFile:read("a")
    dbgP("fuck hibo")
    jsonFile:close()
    timTable = json.decode(jsonData)
  end
  dbgP(sprite.filename .. ".json")
  dbgP(timTable.clutLength)
  
  -- clut and bbp
  local modeByte = 0
  if(timTable.clutBit) then
    modeByte = modeByte + 8
  end
  if(timTable.bbp == 8) then
    modeByte = modeByte + 1
  elseif(timTable.bbp == 16) then
    modeByte = modeByte + 2
  elseif(timTable.bbp == 24) then
    modeByte = modeByte + 3
  end
  timString = timString .. string.char(modeByte, 0, 0, 0)
  
  -- clut
  if(timTable.clutBit) then
    --clutLength
    local byte1 =  timTable.clutLength & 0x000000FF
    local byte2 = (timTable.clutLength & 0x0000FF00) >> 8
    local byte3 = (timTable.clutLength & 0x00FF0000) >> 16
    local byte4 = (timTable.clutLength & 0xFF000000) >> 24
    timString = timString .. string.char(byte1, byte2, byte3, byte4)
    
    -- clutx
    byte1 =  timTable.clutX & 0x00FF
    byte2 = (timTable.clutX & 0xFF00) >> 8
    dbgP(byte2)
    timString = timString .. string.char(byte1, byte2)
    
    -- cluty
    byte1 =  timTable.clutY & 0x00FF
    byte2 = (timTable.clutY & 0xFF00) >> 8
    timString = timString .. string.char(byte1, byte2)
    
    -- clutWidth
    byte1 =  timTable.clutWidth & 0x00FF
    byte2 = (timTable.clutWidth & 0xFF00) >> 8
    timString = timString .. string.char(byte1, byte2)
    
    -- clutHeight
    byte1 =  timTable.clutHeight & 0x00FF
    byte2 = (timTable.clutHeight & 0xFF00) >> 8
    timString = timString .. string.char(byte1, byte2)
    
    
    -- fucking colors
    local palette = sprite.palettes[1]
    dbgP("colorshit: " .. #palette)
    for c = 0, #palette - 1, 1 do
      byte1 = 0
      local color = palette:getColor(c)
      byte1 = byte1 + (color.red >> 3)
      byte1 = byte1 + ((color.green >> 3) << 5)
      byte1 = byte1 + ((color.blue >> 3) << 10)
      
      if(color.alpha ~= 0) then
        byte1 = byte1 + 0x8000
      end
      
      byte2 = (byte1 & 0xFF00) >> 8
      byte1 = byte1 & 0x00FF
      
      timString = timString .. string.char(byte1, byte2)
    end
  end
  
  
  -- sprite image data
  --imageLength
  local byte1 =  timTable.imageLength & 0x000000FF
  local byte2 = (timTable.imageLength & 0x0000FF00) >> 8
  local byte3 = (timTable.imageLength & 0x00FF0000) >> 16
  local byte4 = (timTable.imageLength & 0xFF000000) >> 24
  timString = timString .. string.char(byte1, byte2, byte3, byte4)
  
  -- imagex
  byte1 =  timTable.imageX & 0x00FF
  byte2 = (timTable.imageX & 0xFF00) >> 8
  timString = timString .. string.char(byte1, byte2)
  
  -- imagey
  byte1 =  timTable.imageY & 0x00FF
  byte2 = (timTable.imageY & 0xFF00) >> 8
  timString = timString .. string.char(byte1, byte2)
  
  -- imageWidth
  byte1 =  timTable.imageWidth & 0x00FF
  byte2 = (timTable.imageWidth & 0xFF00) >> 8
  timString = timString .. string.char(byte1, byte2)
  
  -- imageHeight
  byte1 =  timTable.imageHeight & 0x00FF
  byte2 = (timTable.imageHeight & 0xFF00) >> 8
  timString = timString .. string.char(byte1, byte2)
  
  
  --imagedata TODO
  dbgP(timTable.bbp)
  local fuckshit = Image(sprite)
  --dbgP("stride " .. fuckshit.rowStride)
  --dbgP(fuckshit.width .. " " .. fuckshit.height)
  --dbgP(string.byte(string.sub(fuckshit.bytes, 0, 0)))
  --dbgP(string.byte(string.sub(fuckshit.bytes, 0, 1)))
  if(timTable.bbp == 4) then
    for w = 1, (fuckshit.width * fuckshit.height), 2 do
      byte1 = string.byte(fuckshit.bytes, w) + (string.byte(fuckshit.bytes, w + 1) << 4)
      dbgP(string.byte(fuckshit.bytes, w) .. " " .. string.byte(fuckshit.bytes, w + 1) .. " " .. byte1 )
      timString = timString .. string.char(byte1)
    end
  elseif(timTable.bbp == 8) then
    for w = 1, (fuckshit.width * fuckshit.height), 1 do
      byte1 = string.byte(fuckshit.bytes, w)
      dbgP(string.byte(fuckshit.bytes, w) .. " " .. byte1)
      timString = timString .. string.char(byte1)
    end
  end
  
  
  -- Create file handle and save that tim!
  dbgP(expDlg.data.file)
  local timFile = io.open(expDlg.data.file, "wb")
  timFile:write(timString)
end
