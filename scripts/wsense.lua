-- hx711 config
hx711_scl = 3 -- 4 for wemos D2 mini
hx711_sda = 0

-- I2C config
id = 0
sda = 2      -- GPIO4
scl = 1      -- GPIO5
rtc_addr = 0x68   -- I2C Address

tmr_id = 0
period = 1000 -- milisecond
go_flag = true -- flag for running main program(default:true)

-- utility functions
--
function trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function ls(dir)
	if dir == "flash" then
		file.chdir('/SD0')
	end
	l = file.list();
	for k,v in pairs(l) do
		print("name:"..k..", size:"..v)
	end
	file.chdir('/FLASH')
end

-- html server functions
function htmlServerInit()
-- setup website
	cfg =
	{
			ip="192.168.1.1",
			netmask="255.255.255.0",
			gateway="192.168.1.1"
	}
	html_p = '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8" /><title>Status</title></head><body><h1>Current Load (in converted|RAW): %d|%d </h1><form action="" method="post"><table><tr><td><button name="foo" value="bar">Calibrate</button></td></tr><tr><td>Point A:</td><td><input type="text" name="cal1a" value="%d"></td><td><input type="text" name="cal1b" value="%d"></td></tr><tr><td>Point B:</td><td><input type="text" name="cal2a" value="%d"></td><td><input type="text" name="cal2b" value="%d"></td></tr></table></form></body></html>'

	wifi.setmode(wifi.SOFTAP)
	wifi.ap.config({ssid="WSENSE"})
	wifi.ap.setip(cfg)
	print(wifi.ap.getip()) -- Dynamic IP Address
	srv=net.createServer(net.TCP,3)
	srv:listen(80,function(conn)
		conn:on("receive", function(client,request)
			_GET = {}
			local a, b, args = string.find(request, "foo=bar&(.*)");
			if (args ~= nil)then
				for k, v in string.gmatch(args, "(%w+)=(-?%w+)&*") do
					_GET[k] = v
					file.open(k,"w")
					file.write(v)
					file.close()
					--print(k..":"..v)
				end
				--args = "$$"..args;
				--print(args)
				-- find equation offset and slope
				-- Y = X*m + T
        slope = (_GET['cal1a'] - _GET['cal2a'])/(_GET['cal1b'] - _GET['cal2b'])
        offset = _GET['cal1a'] - _GET['cal1b']*slope
        file.open("SLOPE","w")
        file.write(slope)
        file.close()
        file.open("OFFSET","w")
        file.write(offset)
        file.close()
      else
        f = file.open("SLOPE")
        if not f then
          file.open("SLOPE","w")
          file.write('1')
          slope = '1'
          file.close()
        else
          slope = file.read()
          file.close()
        end
        f = file.open("OFFSET")
        if not f then
          file.open("OFFSET","w")
          file.write('0')
          offset = '0'
          file.close()
        else
          offset = file.read()
          file.close()
        end
      end
			-- calculate new converted value and send page
			fpage = string.format(html_p,lastdata*slope+offset,lastdata,0,0,0,0)
			client:send(fpage)
			collectgarbage();
		end)
	end)
end


-- hx711 functions
--
lastdata = 0
function hx711_resume(period) --miliseconds
  tmr.alarm(tmr_id, period, 1, function()
    lastdata = hx711.read(0)
    file.open("/SD0/"..filename,"a+")
    file.writeline(string.format("0x%x",lastdata))
    file.close()
    print(string.format("0x%02x",lastdata)..string.format(" - %d",lastdata))
    end)
end

function hx711_stop()
  tmr.unregister(tmr_id)
end

function hx711_start(period)
  hx711.init(hx711_scl,hx711_sda)
  hx711_resume(period)
end

-- I2C functions
-- I2C: read from reg_addr content of dev_addr
function read_reg(dev_addr, reg_addr)
  i2c.start(id)
  if i2c.address(id, dev_addr, i2c.TRANSMITTER) == false then
    print("ack missing")
  end
  i2c.write(id, reg_addr)
  i2c.stop(id)
  i2c.start(id)
  if i2c.address(id, dev_addr, i2c.RECEIVER) == false then
    print("ack missing")
  end
  c = i2c.read(id, 1)
  i2c.stop(id)
  return c
end

-- I2C: write to reg_addr of dev_addr
function write_reg(dev_addr, reg_addr, val)
  i2c.start(id)
  if i2c.address(id, dev_addr, i2c.TRANSMITTER) == false then
    print("ack missing")
  end
  i2c.write(id, reg_addr,val)
  i2c.stop(id)
end

-- RTC functions
-- I2C/RTC: set time to RTC
function set_time(year,mon,date,hour,min,sec)
  write_reg(rtc_addr,0x07,0x00) -- disable ext osc.
  write_reg(rtc_addr,0x06,year)
  write_reg(rtc_addr,0x05,mon)
  write_reg(rtc_addr,0x04,date)
  write_reg(rtc_addr,0x02,hour)
  write_reg(rtc_addr,0x01,min)
  write_reg(rtc_addr,0x00,sec)
end

-- I2C/RTC: get time from RTC
function get_time()
  year = string.format("%02x",string.byte(read_reg(rtc_addr,0x06)))
  mon  = string.format("%02x",string.byte(read_reg(rtc_addr,0x05)))
  date = string.format("%02x",string.byte(read_reg(rtc_addr,0x04)))
  hour = string.format("%02x",string.byte(read_reg(rtc_addr,0x02)))
  min  = string.format("%02x",string.byte(read_reg(rtc_addr,0x01)))
  sec  = string.format("%02x",string.byte(read_reg(rtc_addr,0x00)))
  return mon..date..hour..min
end

function wsense_setup()
	local go_flag = true
	-- I2C/RTC setup
	i2c.setup(id, sda, scl, i2c.SLOW)
	-- SD control functions
	spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 8)
	-- then mount the sd
	-- note: the card initialization process during `file.mount()` will set spi divider temporarily to 200 (400 kHz)
	-- it's reverted back to the current user setting before `file.mount()` finishes
	vol = file.mount("/SD0", 8)   -- 2nd parameter is optional for non-standard SS/CS pin
	if not vol then
		print("retry mounting")
		vol = file.mount("/SD0", 8)
		if not vol then
			-- TODO: add a retry counter and a restart().(failed X times, do idle 4ver.
			--error("mount failed")
			go_flag = false
		end
	end
	return go_flag
end

function wsense_init()
	local go_flag = true
	if wsense_setup() == false then
    error("HW setup failed")
    go_flag = false
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

	-- THIS IS A BUG, W/O THIS PRINT IT BREAKS
	print('dbg:SD mounted successfully...')
	rtcnow = get_time()
	filename = prefix..string.format("%03d",index)..rtcnow
	print("new file "..filename.." opened")

  htmlServerInit()
	hx711_start(period)
end
