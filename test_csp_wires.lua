pcall(function() print=(require'luapp').print end)
--require'base';
require'csp';
local chan=csp.chan
local spawn=csp.spawn
local alt=csp.alt
local waitall=csp.waitall
local statistic=csp.statistic
local benice=csp.benice

print "hi"

function generator(c,n)
  local i
  for i=1,n do
    c:send(0)
    c:send(1)
  end
end

function foldl(f, init, ...)
  local r = init
  for n=1,select('#',...) do
    local e = select(n,...)
    r = f(r, e)
  end
  return r
end



function asyncbox(f,init,cout,...)
  local channels = {...}
  local state = {}
  local events = {}
  local i
  local out = nil
--  local function func(...)
--    return foldl(function (a, b)
--                    return a==b and 0 or 1
--                 end, 0, ...)
--  end
  local function onchange(v, index)
--    print('onchange', #state, #channels)
    state[index]=v
    if #state==#channels then -- ensure there are no undefined falues in state
--      local newout = func(unpack(state))
      local newout = foldl(f, init, unpack(state))
      if out~=newout then
        out=newout
        cout:send(out)
      end
    end
  end
  -- read async (withount blocking channels which were read)
  for i=1,#channels do
    table.insert(events, {'recv', channels[i], onchange})
  end
  while true do
    alt(events)
  end
end

function xorbox(...) asyncbox(function (a,b) return a~=b and 1 or 0 end,            0, ...) end
function andbox(...) asyncbox(function (a,b) return (a==1 and b==1) and 1 or 0 end, 1, ...) end
function  orbox(...) asyncbox(function (a,b) return (a==1 or b==1) and 1 or 0 end,  0, ...) end


function display(...)
  local channels = {...}
  local state = {}
  local events = {}
  local i
  local function printstate()
    print('++++',state)
--    for _,bit in ipairs() do
--    print('.')
  end
  for i=1,#channels do
    table.insert(events, {'recv', channels[i], function(v, index) state[index]=v printstate() end})
    table.insert(state, '?')
  end
  while true do
    alt(events)
  end
end

local function dump(c, text)
  while true do
    local prime=c:recv()
    print('+++', text, prime)
  end
end

function splitter(cin)
  return setmetatable({cin=cin},
    {__index={
      newout = function()
               end,
      delout = function(cout)
               end
    }})
end


function blackhole_channel() -- todo: singleton
  c = chan()
  spawn(blackhole, c)
end

function blackhole(cin) -- todo: singleton
  while true do
    cin:recv()
  end
end

-- Constructs a channel that forever outputs the specified value
function whitehole_channel(v) -- todo: singleton for each 'v'
  cout = chan()
  spawn(whitehole, cout, v)
end


-- A process that forever outputs the specified value
function whitehole(cout, v) -- todo: singleton for each 'v'
  while true do
    cout:send(v)
  end
end

function varbox(cin,cout)
  local value = nil
  while true do
    alt{
      {'recv', cin,  function(v) value=v end},
      {'send', cout, value},
    }
  end
end

function varbox2(cbi)
  local value = nil
  while true do
    alt{
      {'recv', cbi, function(v) value=v end},
      {'send', cbi, value},
    }
  end
end


function ivarbox(cin,cout)
  local value = nil
  while true do
    if value==nil then
      alt{
        {'recv', cin,  function(v) value=v end},
      }
    else
      alt{
        {'recv', cin,  function(v) --[[ cin:poison() ]] end},
        {'send', cout, value},
      }
    end
  end
end



-- very straightforward and inefficient implementation of MVar (as it works in Haskell CML)
-- an advantage is using only basic channel operations
-- it would allow the mvar to work over networked channels
function mvar()
  local function mvarbox() -- cput, cget, ctake, cpeek
    local value = nil
    while true do
      if value==nil then
        alt{
          -- write to empty mvar
          -- readers are waiting until mvar is not empty
          {'recv', cput,  function(v) value=v end},
          -- non-destructive read, can read empty mvar
          {'send', cpeek,  value},
        }
      else
        alt{
          -- write to mvar
          -- put(nil) is the first way to make mvar empty
          -- put(_)   should raise an exception
          {'recv', cput,  function(v) if v==nil then value=v --[[ else cin:send_exc() ]] end end},
          -- non-destructive read, can read empty mvar
          {'send', cpeek,  value},
          -- non-destructive read, blocks on empty mvar
          {'send', cget,  value},
          -- destructive read
          -- take() is the second way to make mvar empty
          {'send', ctake, value, function(v) value=nil end},
        }
      end
    end
  end

  cput = chan()
  cget = chan()
  ctake= chan()
  cpeek= chan()
  spawn(mvarbox)
  return {
    put  = function(self,...) return cput:send(...)  end,
    get  = function(self,...) return cget:recv(...)  end, -- alt(SyncVar.iGetEvt)
    take = function(self,...) return ctake:recv(...) end,
    peek = function(self,...) return cpeek:recv(...) end,
  }
end

function test_mvar()
  mv = mvar()
  spawn(function() print('+???+', mv:get()) end)
  spawn(function() mv:put(666) end)
  spawn(function() print('+???+', mv:get()) end)
  print ("+666+", mv:take())
  mv:put(777)
  print ("+777+", mv:get())

end


function semaphore(value)
  local function semaphorebox() -- value, center, cleave
    while true do
      if value==0 then -- blocked semaphore
        --alt{{'recv', cleave,         function() value=value+1 end}}
        cleave:recv()
        value=value+1
      end
      alt{{'send', center,  value, function() value=value-1 end},
          {'recv', cleave,         function() value=value+1 end}}
    end
  end

  center = chan()
  cleave = chan()
  spawn(semaphorebox)
  return {
    enter  = function(self) return center:recv()  end,
    leave  = function(self) return cleave:send()  end,
  }
end

function test_semaphore()
  local function dump(c, text)
    while true do
      local prime=c:recv()
      print('+++', text, prime)
    end
  end

  printer = chan()
  spawn(dump, printer, '|')

  semprinter = semaphore(1)

  spawn(function()
      semprinter:enter()
      printer:send('a')
      printer:send('b')
      printer:send('c')
      semprinter:leave()
  end)
  spawn(function()
      semprinter:enter()
      printer:send('A')
      printer:send('B')
      printer:send('C')
      semprinter:leave()
  end)
  spawn(function()
      semprinter:enter()
      printer:send('1')
      printer:send('2')
      printer:send('3')
      semprinter:leave()
  end)

end

test_semaphore()
test_mvar()



--lazy,
--i-structure


--old_os_exit = os.exit
--os.exit = function() waitall() old_os_exit() end
waitall()
--os.exit()
--[[
]]


c1=chan()
c2=chan()
c3=chan()
c4=chan()
c5=chan()
c6=chan()
spawn(generator,c1,10)
spawn(generator,c2,10)
spawn(xorbox,c3,c1,c2)
--spawn(andbox,c4,c1,c2)
--spawn( orbox,c5,c1,c2)
spawn(xorbox,c6,c1,c2)

spawn(dump, c3, 'c3')
--spawn(dump, c4, 'c4\t')
--spawn(dump, c5, 'c5\t\t')
spawn(dump, c6, 'c6\t\t\t')

--spawn(display,c1,c2,c3)
--spawn(display,c1,c2)
--spawn(display,c3,c4,c5)

waitall()
