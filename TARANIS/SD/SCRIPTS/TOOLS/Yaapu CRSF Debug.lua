
local CRSF_FRAME_CUSTOM_TELEM = 0x80
local CRSF_FRAME_CUSTOM_TELEM_LEGACY = 0x7F
local CRSF_CUSTOM_TELEM_PASSTHROUGH = 0xF0
local CRSF_CUSTOM_TELEM_STATUS_TEXT = 0xF1
local CRSF_CUSTOM_TELEM_PASSTHROUGH_ARRAY = 0xF2

local packetCount = {
  [0x5000] = 0,
  [0x5001] = 0,
  [0x5002] = 0,
  [0x5003] = 0,
  [0x5004] = 0,
  [0x5005] = 0,
  [0x5006] = 0,
  [0x5007] = 0,
  [0x5008] = 0,
  [0x5009] = 0,
  [0x500A] = 0,
  [0x500B] = 0,
}

local logfilename
local logfile
local flushtime = getTime()

local function processTelemetry(data_id, value)
  if packetCount[data_id] ~= nil then
    packetCount[data_id] = packetCount[data_id] + 1
  end
  io.write(logfile, getTime(), ";0;", data_id, ";", value, "\r\n")             
end

local function crossfirePop()
    local command, data = crossfireTelemetryPop()
    -- command is 0x80 CRSF_FRAMETYPE_ARDUPILOT
    if (command == CRSF_FRAME_CUSTOM_TELEM or command == CRSF_FRAME_CUSTOM_TELEM_LEGACY)  and data ~= nil then
      -- actual payload starts at data[2]
      if #data >= 7 and data[1] == CRSF_CUSTOM_TELEM_PASSTHROUGH then
        local app_id = bit32.lshift(data[3],8) + data[2]
        local value =  bit32.lshift(data[7],24) + bit32.lshift(data[6],16) + bit32.lshift(data[5],8) + data[4]
        return 0x00, 0x10, app_id, value
      elseif #data > 4 and data[1] == CRSF_CUSTOM_TELEM_STATUS_TEXT then
        return 0x00, 0x10, 0x5000, 0x00000000
      elseif #data > 48 and data[1] == CRSF_CUSTOM_TELEM_PASSTHROUGH_ARRAY then
        -- passthrough array
        local app_id, value
        for i=0,data[2]-1
        do
          app_id = bit32.lshift(data[4+(6*i)],8) + data[3+(6*i)]
          value =  bit32.lshift(data[8+(6*i)],24) + bit32.lshift(data[7+(6*i)],16) + bit32.lshift(data[6+(6*i)],8) + data[5+(6*i)]
          --pushMessage(7,string.format("CRSF:%d - %04X:%08X",i, app_id, value))
          processTelemetry(app_id, value)
        end
      end
    end
    return nil, nil ,nil ,nil
end

local function getLogFilename()
  local datenow = getDateTime()  
  local info = model.getInfo()
  local modelName = string.lower(string.gsub(info.name, "[%c%p%s%z]", ""))
  return modelName..string.format("-%04d%02d%02d_%02d%02d%02d.plog", datenow.year, datenow.mon, datenow.day, datenow.hour, datenow.min, datenow.sec)
end

local function background()
  for i=1,5
  do
    local sensor_id,frame_id,data_id,value = crossfirePop()
    if frame_id == 0x10 then
      if packetCount[data_id] ~= nil then
        packetCount[data_id] = packetCount[data_id] + 1
      end
      io.write(logfile, getTime(), ";0;", data_id, ";", value, "\r\n")             
    end
  end
  
  if getTime() - flushtime > 50 then
    -- flush
    pcall(io.close,logfile)
    logfile = io.open("/LOGS/"..logfilename,"a")
    
    flushtime = getTime()
  end  
end

local function run(event)
  background()
  lcd.clear()
  lcd.drawText(1,1,"YAAPU CRSF DEBUG 1.1",SMLSIZE)  
  
  lcd.drawText(1,11,string.format("5000: %d", packetCount[0x5000]),SMLSIZE)
  lcd.drawText(1,20,string.format("5001: %d", packetCount[0x5001]),SMLSIZE)
  lcd.drawText(1,29,string.format("5002: %d", packetCount[0x5002]),SMLSIZE)
  lcd.drawText(1,38,string.format("5003: %d", packetCount[0x5003]),SMLSIZE)
  lcd.drawText(1,47,string.format("5004: %d", packetCount[0x5004]),SMLSIZE)
  
  lcd.drawText(63,11,string.format("5005: %d", packetCount[0x5005]),SMLSIZE)
  lcd.drawText(63,20,string.format("5006: %d", packetCount[0x5006]),SMLSIZE)
  lcd.drawText(63,29,string.format("5007: %d", packetCount[0x5007]),SMLSIZE)
  lcd.drawText(63,38,string.format("5008: %d", packetCount[0x5008]),SMLSIZE)
  lcd.drawText(63,47,string.format("5009: %d", packetCount[0x5009]),SMLSIZE)
  
  lcd.drawText(125,11,string.format("500A: %d", packetCount[0x500A]),SMLSIZE)
  lcd.drawText(125,20,string.format("500B: %d", packetCount[0x500B]),SMLSIZE)
  
  lcd.drawText(1,LCD_H-7,tostring(logfilename),SMLSIZE)
  collectgarbage()
  collectgarbage()
  return 0
end

local function init()
  logfilename = getLogFilename()
  logfile = io.open("/LOGS/"..logfilename,"a")
  io.write(logfile, "counter;f_time;data_id;value\r\n")  
end

return {run=run, init=init}


