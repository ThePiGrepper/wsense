count= 0

tmr.alarm(0,1000,tmr.ALARM_AUTO,function()
  count = count + 1
  end)

cfg =
{
    ip="192.168.1.1",
    netmask="255.255.255.0",
    gateway="192.168.1.1"
}
html_p = '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8" /><title>Status</title></head><body><h1>Status:%d</h1><form action="" method="post"><table><tr><td><button name="foo" value="bar">Calibrate</button></td></tr><tr><td>Point A:</td><td><input type="text" name="cal1a" value="%d"></td><td><input type="text" name="cal1b" value="%d"></td></tr><tr><td>Point B:</td><td><input type="text" name="cal2a" value="%d"></td><td><input type="text" name="cal2b" value="%d"></td></tr></table></form></body></html>'

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
				print(k..":"..v)
			end
			args = "$$"..args;
			print(args)
		end
		fpage = string.format(html_p,count,0,0xfffffeee,180,0xffff3e3e)
		client:send(fpage)
		collectgarbage();
	end)
end)
