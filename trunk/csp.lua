--require'luapp';
--local pp = luapp.pp;

--function pprint(...)
--  for n=1,select('#',...) do
--    local e = select(n,...)
--    io.write(pp(e,nil,10000,1.0)," ")
--  end
--  print()
--end
--local pprint=pprint



local pairs=pairs
local ipairs=ipairs
local math=math -- max, random
local print=print
local table=table
local error=error
local unpack=unpack
local setmetatable=setmetatable
local type=type
local assert=assert
local coroutine=coroutine

math.randomseed( os.time() )

module(...)




function current()
  return coroutine.running() or 'main'
end

active = {main=0}
active_n = 1
procnames = {main='main'}
statistic = {n_threads=1, max_threads=0, max_active_threads=0, }
--procvalues = {}


function sactive() -- for debuging
  local s='['..procnames[current()]..'|'
  for v,_ in pairs(active) do
--    if v~=1 then
--    print(v)
      s=s..' '..procnames[v]
--    end
  end
  return s..']'
end

function handle(status, ...)
  if status then
    return ...
  end
  error(...)
end

function switch(t)
  if current() == 'main' then
    local status, param = coroutine.resume(t)
    if status~=true then              -- assert in coroutine
      disactivate(t)
      error(param)
    elseif param==nil then            -- coroutine ended
      statistic.n_threads = statistic.n_threads-1
      disactivate(t)
      return nil
    elseif param=='main' then         -- switch to main
      return param
    else                              -- switch not to main
      assert( coroutine.status(param)=='suspended' )
      return switch(param)            -- tail recursive
    end
  else
   -- pass 't' as param to main thread, then main will switch to 't'
    return coroutine.yield(t)
    --pprint( coroutine.yield(t, ...) )
    --print('\\-switch.')
  end
end

function randomprocess()--except)
  local keys = {}
--local wasexcept = false
  for proc,_ in pairs(active) do
--    if proc==1 then
--  elseif except~=nil and proc==except then
--    wasexcept = true
--    else
      table.insert(keys, proc)
--    end
  end
  if #keys==0 then
--  if wasexcept then
--    return except
--  else
      return nil
--  end
  else
    return keys[math.random(#keys)]
  end
end



function schedule()
--  pprint('schedule()', sactive())

--  local next = active[1]
--  if active[1]==current() and #active>1 then
--    table.insert(active, table.remove(active, 1))
--    next = active[1]
--  end

  --local next = randomprocess(current()) --
  local next = randomprocess() --
--  print('next', next)

    if next==nil then
      print('AAAAAAAAAAA', sactive())
      --return nil
      assert(false)
    end

  if next==current() then
     return nil
  end

  while true do
--  if active[1]==0 then print('no more threads', sactive()) os.exit() end
--    if #active==0 then
--       return nil
--    end


    local v = switch(next)
--  next = active[1]

    --next = randomprocess(current())
    next = randomprocess()
    if next==nil then
      print('AAAAAAAAAAA', sactive())
      --return nil
      assert(false)
    end


--    print('next=',procnames[next])
    if next==current() then
      return nil
    end
--    pprint('schedule--', sactive())
  end
end

benice = schedule

function activate(t) -- , value
  assert(active[t]==nil)
  active[t] = 0 -- value or 0
  active_n = active_n+1
  statistic.max_active_threads = math.max(statistic.max_active_threads, active_n)
--  if math.random(2)==1 then schedule() end
--  schedule()
end

function disactivate(t)
  assert(active[t]~=nil)
  active[t] = nil
  active_n = active_n-1

  if t==current() then
    schedule()
  end

end


function waitall()
--  while not (#active==0 or (#active==1 and active[1]==current())) do
  while active_n>1 do
    schedule()
  end
  assert(active[current()]~=nil)
end

function chan(options)
  options = options or {}
  if options.buffer then
    error('todo: buffered channel')
  else
  return setmetatable(
  {
    rdq = {},
    wrq = {},
--    value = nil,
  },
  {__index = {
    split       = nil,
    wait        = nil,
--  waitjoin    = nil,
    wait_needed = nil,
    nbrecv      = nil,
    nbsend      = nil,
    sendn       = nil,
    recvn       = nil,
    send_lazy   = nil,
    send_promise= nil,
    send_exc    = nil,
    poison      = nil,
    canrecv     = function(self, v) return 0 ~= #self.wrq end,
    recv        = function(self) -- todo: guard
                    --pprint('recv', c, sactive())
                    if 0 ~= #self.wrq then
                      -- a writer is waiting
                      local writer, v, delhooks, magic = unpack(table.remove(self.wrq, 1))
                      --pprint(procnames[current()],'recv: a writer is waiting', v, delhooks, procnames[writer])
                      if delhooks~=nil then delhooks(magic, v) end
                      activate(writer)
                      return v
                    else
                      -- there is no writer, wait for one
                      --pprint(procnames[current()],'recv: there is no writer, wait for one')
                      local refv={current(),nil} -- nil is placeholder
                      table.insert(self.rdq, refv)
                      disactivate(current())
                      return refv[2]
                    end
                  end,
    cansend     = function(self, v) return 0 ~= #self.rdq end,
    send        = function(self, v)
                    --pprint('send',c,v, sactive())
                    if 0 ~= #self.rdq then
                      -- a reader is waiting
                      local refv = table.remove(self.rdq, 1)
                      local reader = refv[1]
                      --pprint(procnames[current()],'send: a reader is waiting', refv, procnames[reader])
                      refv[2] = v
                      -- if it was 'alt', and it was choosed - its other hooks must be removed here, before switching!
                      if refv[3]~=nil then refv[3](refv[4], v) end
                      activate(reader)
                    else
                      --pprint(procnames[current()],'send: there is no reader, wait for one')
                      -- there is no reader, wait for one
                      table.insert(self.wrq, {current(),v})
                      disactivate(current())
                    end
                  end
  }})
  end
end

-- spawn(f, params)
-- spawn(name, f, params)
function spawn(f, ...)
  local name='f'
  local params = {...}
  if type(f)=='string' then
    name,f=f,table.remove(params, 1)
  end
  assert(type(f)=='function')

--  pprint('coro.create', params) -- , pp(debug.getinfo(f,'n'))
  local co = coroutine.create(function()
--                                print("coroutine started")
                                f(unpack(params))
                                --assert( current()==table.remove(active, 1) )
                                --assert(false)
                                --disactivate(current())
                                --procnames[current()] = nil
--                                print("coroutine ended")
                              end)
  procnames[co] = name
  statistic.n_threads = statistic.n_threads+1
  statistic.max_threads = math.max(statistic.max_threads, statistic.n_threads)


  activate(co)
--  if math.random(2)==1 then schedule() end
--    schedule()
end


function filter_itable_inplace(t, p)
  local i=1
  while i<=#t do
    if not p(t[i]) then
      table.remove(t, i)
    else
      i=i+1
    end
  end
  return t
end


function alt(events)
  local ready = {}
  local evt

--  pprint(events)
  for i,evt in ipairs(events) do
    if (evt[1]=='recv' and evt[2]:canrecv())
    or (evt[1]=='send' and evt[2]:cansend())
--  or (evt[1]=='timeout' and curtime>=altstart+evt[2])
--  or (evt[1]=='attime' and curtime>=evt[2])
--  or (evt[1]=='join' and isdead(evt[2]))
    then
      table.insert(ready, i)
    end
  end
--  pprint('++ready',ready)
  local timeout = events.timeout
  local nblock = events.timeout==0

  if #ready~=0 then
    -- If more than one channel can communicate, a nondeterministic choice is made.
    -- it is the first place of non-determinant choice
    local index = ready[math.random(#ready)]
    local evt = events[index]
    --pprint('evt',evt)
    if evt[1]=='recv' then
      local _,ch,action = unpack(evt)
      v = ch:recv()
      if action~=nil then action(v, index, ch) end
    elseif evt[1]=='send' then
      local _,ch,v,action = unpack(evt)
      ch:send(v)
      if action~=nil then action(v, index, ch) end
    end
    return index

  elseif nblock then
    return 0
  else
    -- If no channel can communicate, the process suspends until one can

    -- upvalues for delhooks()
    local curt = current()
--    local peert = nil -- the peer to communicate with
    local index = nil -- index of fired event

    -- callback executed in sender's thread
    -- upvalues are events, curt, vreceved, chanother,action
    local function delhooks(...)
      index, vreceived = ...

--      print('++delhooks')
      for _,evt in ipairs(events) do
      --for i=1,#events do
        local m,ch,_ = unpack(evt)
        if m=='recv' then
          filter_itable_inplace(ch.rdq, function(refv) return refv[1]~=curt end)
        elseif m=='send' then
          filter_itable_inplace(ch.wrq, function(refv) return refv[1]~=curt end)
        end
      end
    end

--    print('#events', #events, events)

    -- the secont place of non-determinant choice
    -- todo: random order (or random single choice) of hooks set on the same channel at the same time
    -- todo: read both write alerts set at once on the same channel must not communicate,
    for i,evt in ipairs(events) do
    --for evt in ivalues(events) do
      if evt[1]=='recv' then
        local _,ch,action = unpack(evt)
        local refv={current(),0,delhooks,i} -- 0 is placeholder
        table.insert(ch.rdq, refv)
      elseif evt[1]=='send' then
        local _,ch,v,action = unpack(evt)
        local refv={current(),v,delhooks,i}
        table.insert(ch.wrq, refv)
      end
    end

--    print('#events', #events, events)

    disactivate(current())

--    print('index',index)
    assert(index~=nil and 0<index and index<=#events)

    local evt = events[index]
      if evt[1]=='recv' then
        local _,ch,action = unpack(evt)
        if action~=nil then action(vreceived, index, ch) end
      elseif evt[1]=='send' then
        local _,ch,v,action = unpack(evt)
        if action~=nil then action(v, index, ch) end
      end
    return index
  end
end
