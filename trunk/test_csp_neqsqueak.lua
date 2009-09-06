--require'luapp';
--local pp = luapp.pp;

require'csp';
local chan=csp.chan
local spawn=csp.spawn
local alt=csp.alt
local waitall=csp.waitall
local statistic=csp.statistic

print "hi"

-- chan
-- alt
--  recv
--  send
--  timeout
--  attime
--  never
--  always
--  join
-- spawn
-- sleep?




--
--  newsqueak tests
--
function test_sieve()
  local function counter(en, c)               --  counter:=prog(end: int, c: chan of int)
    local i                                   --  {
    for i=2,en-1 do                           --    i:int;
      c:send(i)                               --    for(i=2; i<end; i++)
    end                                       --      c<-=i;
  end                                         --  };

  local function filter(prime, listen, send)  --  filter:=prog(prime: int, listen: chan of int, send: chan of int)
    while true do                             --  {
      local i=listen:recv()                   --    i:int;
      if 0~=(i%prime) then                    --    for(;;)
        send:send(i)                          --      if((i=<-listen)%prime)
      end                                     --        send<-=i;
    end                                       --  };
  end

  local function sieve(c)                     --  sieve:=prog(c: chan of int)
    while true do                             --  {
      local prime=c:recv()                    --    for(;;){
      print('+++test_sieve\t', prime)         --      prime:=<-c;
      local newc=chan()                       --      print(prime, " ");
      spawn(filter, prime, c, newc)           --      newc:=mk(chan of int);
      c=newc                                  --      begin filter(prime, c, newc);
    end                                       --      c=newc;
  end                                         --    }
                                              --  };
--local function dump(c)
--  while true do
--    local prime=c:recv()
--    print('+++dump', prime, " ")
--  end
--end

  local count=chan()                          --  count:=mk(chan of int);
  spawn(counter, 100, count);                 --  begin counter(100, count);
--  spawn('dump', dump, count);
  spawn(sieve, count);                        --  begin sieve(count);
end


function test_sieve1()
  local function counter(c)                   --  counter:=prog(c: chan of int)
    local i=1                                 --  {
    while true do                             --    i:=1;
      i=i+1                                   --    for(;;)
      c:send(i)                               --      c<-=(i=i+1);
    end                                       --  };
  end

  local function filter(prime, listen, send)  --  filter:=prog(prime: int, listen: chan of int, send: chan of int)
    while true do                             --  {
      local i=listen:recv()                   --    i:int;
      if 0~=(i%prime) then                    --    for(;;)
        send:send(i)                          --      if((i=<-listen)%prime)
      end                                     --        send<-=i;
    end                                       --  };
  end

  local function sieve(prime)                 --  sieve:=prog(prime: chan of int)
    local c=chan()                            --  {
    spawn(counter, c)                         --    c:=mk(chan of int);
    while true do                             --    begin counter(c);
      local p=c:recv()                        --    newc:chan of int;
      prime:send(p)                           --    p:int;
      local newc=chan()                       --    for(;;){
      spawn(filter, p, c, newc)               --      prime<-=p=<-c;
      c=newc                                  --      newc=mk();
    end                                       --      begin filter(p, c, newc);
  end                                         --      c=newc;
                                              --    }
                                              --  };

  local prime=chan()                          --  prime:=mk(chan of int);
  spawn(sieve, prime);                        --  begin sieve(prime);
  print('+++test_sieve1',                     --
        prime:recv(),                         --  <-prime;
        prime:recv(),                         --  <-prime;
        prime:recv(),                         --  <-prime;
        prime:recv())                         --  <-prime;
end


function test_sieve2()
  local function counter(en, c)               --  counter:=prog(end: int, c: chan of int)
    local i                                   --  {
    for i=2,en-1 do                           --    i:int;
      c:send(i)                               --    for(i=2; i<end; i++)
    end                                       --      c<-=i;
  end                                         --  };

  local function filter(listen, send)         --  filter:=prog(listen: chan of int, send: chan of int)
    local prime=listen:recv()                 --  {
    print('+++test_sieve2\t\t', prime)        --    i:int;
    while true do                             --    prime:=<-listen;
      local i=listen:recv()                   --    print(prime, " ");
      if 0~=(i%prime) then                    --    for(;;)
        send:send(i)                          --      if((i=<-listen)%prime)
      end                                     --        send<-=i;
    end                                       --  };
  end

  local function sieve(c)                     --  sieve:=prog(c: chan of int)
    local n=1                                 --  {
    --while true do                           --    for(;;){
    for i=1,200 do                            --      newc:=mk(chan of int);
      local newc=chan()                       --      begin filter(c, newc);
      spawn(filter, c, newc)                  --      c=newc;
      c=newc                                  --    }
    end                                       --  };
  end

  local count=chan()                          --  count:=mk(chan of int);
  spawn(counter, 100, count);                 --  begin counter(100, count);
  spawn(sieve, count);                        --  begin sieve(count);
end


function test_sieve3()
  local function counter(en, c)               --  counter:=prog(end: int, c: chan of int)
    local i                                   --  {
    for i=2,en-1 do                           --    i:int;
      c:send(i)                               --    for(i=2; i<end; i++)
    end                                       --      c<-=i;
  end                                         --  };

  local function filter(listen)               --  filter:=prog(listen: chan of int)
    local prime=listen:recv()                 --  {
    print('+++test_sieve3\t\t\t', prime)      --    i:int;
    local send=chan()                         --    prime:=<-listen;
    spawn(filter, send)                       --    print(prime, " ");
    while true do                             --    send:=mk(chan of int);
      local i=listen:recv()                   --    begin filter(send);
      if 0~=(i%prime) then                    --    for(;;)
        send:send(i)                          --      if((i=<-listen)%prime)
      end                                     --        send<-=i;
    end                                       --  };
  end

  local count=chan()                          --  count:=mk(chan of int);
  spawn(counter, 100, count);                 --  begin counter(100, count);
  spawn(filter, count);                       --  begin filter(count);
end




function test_select1()
  local function c(c1, c2)
    while true do
      alt{
        {'recv', c1, function(i) print("+++(case 1 ", i, '','','',")") end},
        {'recv', c2, function(i) print("+++(case 2 ",'', i, '','',")") end},
        {'recv', c1, function(i) print("+++(case 3 ",'','', i, '',")") end},
        {'recv', c2, function(i) print("+++(case 4 ",'','','', i, ")") end},
      }
    end
  end

  local function p(n, ch)
    local i
    for i=0,9 do
      ch:send(n)
      n = n+1
    end
  end

  local c1=chan()
  local c2=chan()

  spawn( 'p1', p, 111111, c1)
  spawn( 'p2', p, 222222, c2)
  spawn( 'c',  c, c1, c2)
end

function test_select2()
  local function c(c1, c2, c3, n)
    while true do
      alt{
        {'recv', c1,    function(i) print("+++(case 1 ", i, '','','',")") end},
        {'recv', c1,    function(i) print("+++(case 2 ",'', i, '','',")") end},
        {'send', c2, n, function(i) print("+++(case 3 ",'','','', i, '','','',")") end},
        {'send', c2, n, function(i) print("+++(case 4 ",'','','','', i, '','',")") end},
        {'send', c3, n, function(i) print("+++(case 5 ",'','','','','','', i, ")") end},
      }
      n=n+1
    end
  end

  local function p(n, c)
    local i
    for i=1,10 do c:send(n) n=n+1 end
  end

  local function q1(c)
    local i
    for i=1,10 do
      print("+++(Q1  ", c:recv(), '')
    end
  end

  local function q2(c)
    local i
    for i=1,10 do
      print("+++(Q2  ",'', c:recv())
    end
  end

  c1 = chan()
  c2 = chan()
  c3 = chan()

  spawn( p, 111111, c1)
  spawn( 'q1', q1, c2)
  spawn( 'q2', q2, c3)
  spawn( 'c', c, c1, c2, c3, 222222)
end


function test_blockselect()
  local function c(c1)
    local j
    while true do
      alt{
        {'recv', c1[1].req, function(i) print("+++1",i) end},
        {'recv', c1[2].req, function(i) print("+++2",i) end},
      }
    end
  end

  local cc={{req=chan(), dat=chan()},
            {req=chan(), dat=chan()}}

  spawn(function()
          cc[2].req:send(5)
          cc[1].req:send(5)
        end)

  spawn(c, cc)

  cc[2].req:send(6)
  cc[1].req:send(6)
end


--print(c1:recv)
--print(c2:recv)

test_sieve()
test_sieve1()
test_sieve2()
test_sieve3()
--test_select1()
test_select2()
--test_blockselect()
--waitall()

print('+++----------------------')

--test2()
waitall()
--print('++++',statistic)