scl = 3
sda = 0
tmr_id = 0

period = 1000 -- milisecond
go_flag = true -- flag for running main program(default:true)

-- utility functions
--
function trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- hx711 functions
--
data_cnt = 0
function hx711_resume(period) --miliseconds
  tmr.alarm(tmr_id, period, 1, function()
    data = hx711.read(0)
    file.open("/SD0/"..filename,"a+")
    file.writeline(string.format("0x%x",data))
    file.close()
    print(string.format("0x%02x",data))
    end)
end

function hx711_stop()
  tmr.unregister(tmr_id)
end

function hx711_start(period)
  hx711.init(scl,sda)
  hx711_resume(period)
end

-- SD control functions
--
spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 8)

-- initialize other spi slaves

-- then mount the sd
-- note: the card initialization process during `file.mount()` will set spi divider temporarily to 200 (400 kHz)
-- it's reverted back to the current user setting before `file.mount()` finishes
vol = file.mount("/SD0", 8)   -- 2nd parameter is optional for non-standard SS/CS pin
if not vol then
  print("retry mounting")
  vol = file.mount("/SD0", 8)
  if not vol then
    -- TODO: add a retry counter and a restart().(failed X times, do idle 4ver.
    error("mount failed")
    go_flag = false
  end
end

-- init program
-- load variables
-- check config files
-- PREFIX config file
f = file.open("PREFIX") 
if not f then
  print("PREFIX file not found")
	prefix = ""
  go_flag = false
else
	prefix = trim(file.read())
	file.close()
end
--NEXTINDEX config file
f = file.open("NEXTINDEX")
if not f then
	print("Creating NEW NEXTINDEX file")
	f = file.open("NEXTINDEX","w")
	file.writeline('1')
	file.close()
	index = "0"
else
	index = trim(file.read())
	file.close()
	file.open("NEXTINDEX","w")
	local tmp = index + 1
	file.writeline(string.format("%d",tmp))
	file.close()
end

filename = prefix.."_"..string.format("%04d",index)
print("new file "..filename.." opened")

hx711_start(period)
