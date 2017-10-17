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
html_pre = '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8" /><title>Status</title></head><body><h1>Status:'
html_pos = '</h1></body></html>'

wifi.setmode(wifi.SOFTAP)
wifi.ap.config({ssid="WSENSE"})
wifi.ap.setip(cfg)
print(wifi.ap.getip()) -- Dynamic IP Address
srv=net.createServer(net.TCP,3)
srv:listen(80,function(conn)
    conn:on("receive", function(client,request)
        client:send(html_pre..count..html_pos)
        collectgarbage();
    end)
end)

