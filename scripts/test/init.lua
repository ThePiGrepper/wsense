tmr.alarm(0,2000,tmr.ALARM_SINGLE,function()
  dofile('wsense.lua')
  end)

tmr.alarm(1,20000,tmr.ALARM_SINGLE,function()
  node.restart()
  end)

