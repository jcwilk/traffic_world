pico-8 cartridge // http://www.pico-8.com
version 15
__lua__
--traffic world
--by john wilkinson

-- start ext ./utils.lua

make_pool = (function()
 local function each(pool,f)
  for v in all(pool.store) do
   if v.alive then
    f(v)
   end
  end
 end

 local function sort_by(pool,sort_value_f)
  pool:each(function(m)
   m._sort_value=sort_value_f(m)
  end)

  -- http://www.lexaloffle.com/bbs/?tid=2477
  local a=pool.store
  for i=1,#a do
   local j = i
   while j > 1 and a[j-1]._sort_value < a[j]._sort_value do
    a[j],a[j-1] = a[j-1],a[j]
    j = j - 1
   end
  end
 end

 local function is_any(pool)
  local res = false
  pool:each(function(m)
   res = true
  end)
  return res
 end

 local function min(pool,key)
  local min
  pool:each(function(m)
   if not min then
    min = m[key]
   elseif m[key] < min then
    min = m[key]
   end
  end)
  return min
 end

 local function max(pool,key)
  local min
  pool:each(function(m)
   if not min then
    min = m[key]
   elseif m[key] > min then
    min = m[key]
   end
  end)
  return min
 end

 local function count(pool)
  local res=0
  for i=1,#pool.store do
   if pool.store[i].alive then
    res+=1
   end
  end
  return res
 end

 local function kill(obj)
  obj.alive = false
 end

 return function(store)
  store = store or {}
  local id_counter = 0
  return {
   each = each,
   store = store,
   sort_by = sort_by,
   is_any = is_any,
   min = min,
   max = max,
   count = count,
   make = function(obj)
    obj = obj or {}
    obj.alive = true
    local id = false

    for k,v in pairs(store) do
     if not v.alive then
      id = k
     end
    end

    if not id then
     id_counter+= 1
     id = id_counter
    end
    store[id] = obj
    obj.kill = kill
    return obj
   end
  }
 end
end)()

-- end ext

-- start ext ./lanes.lua
make_lane = (function()
 local offset_threshold = 30
 local min_velocity = .25
 local max_velocity = .5

 local function draw_lane(lane)
  lane.floaters:each(function(f)
   f:draw(lane)
  end)

  local car
  local total_offset = lane.offset
  local first_to_draw = flr((camera_y-total_offset) / car_space_height)
  local last_to_draw = first_to_draw + ceil(128 / car_space_height) + 1

  if #lane.linkers > 0 and last_to_draw >= 1 and first_to_draw <= #lane.linkers then
   first_to_draw = max(1,first_to_draw)
   last_to_draw = min(#lane.linkers,last_to_draw)

   for i=first_to_draw,last_to_draw do
    lane.linkers[i]:draw()
   end
  end

  lane.joiners:each(function(j)
   j:draw(lane)
  end)
 end

 local function update_lane(lane)
  lane.offset+=lane.v
  if lane.offset > offset_threshold and lane.v > -min_velocity then
   lane.v-= rnd(max_velocity-min_velocity)
  elseif lane.offset < -offset_threshold and lane.v < min_velocity then
   lane.v+= rnd(max_velocity-min_velocity)
  end

  lane.joiners:each(function(j)
   j:update(lane)
  end)
  lane.floaters:each(function(f)
   f:update(lane)
  end)
 end

 local function try_lane_switch_from_neighbor(lane_to, lane_from)
  if lane_to:has_joiners() then
   return
  end

  local y = lane_to:get_tail_y()+car_space_height

  local target_index = lane_from:get_car_index_at_y(y)

  if target_index > 0 and target_index <= #lane_from.linkers then
   local linker = lane_from.linkers[target_index]

   local min_floater = lane_to.floaters:min('y')

   if min_floater and min_floater <= linker:get_y() + car_space_height then
    return
   end

   if linker.car.is_player then
    return
   end

   lane_to:crash_in(linker.car,linker:get_y())
   lane_from:remove_car_at(target_index)
  end
 end

 local function get_tail_y(lane)
  return lane.offset + #lane.linkers * car_space_height
 end

 local function linker_draw(linker)
  linker.car:draw(lane_index_to_car_x(linker.lane.index),linker:get_y())
 end

 local function linker_get_y(linker)
  return linker.lane.offset + (linker.car_index-1) * car_space_height
 end

 local function make_linker(lane,car,car_index)
  return {
   lane=lane,
   car=car,
   car_index=car_index,
   draw=linker_draw,
   get_y=linker_get_y
  }
 end

 local function lane_append_car(lane,car)
  add(lane.linkers,make_linker(lane,car,#lane.linkers+1))
 end

 local function lane_has_joiners(lane)
  return lane.joiners:is_any()
 end

 local function get_car_index_at_y(lane,y)
  return ceil((y-lane.offset) / car_space_height)
 end

 local function lane_remove_car_at(lane,car_index)
  local linker
  for i = #lane.linkers,car_index+1,-1 do
   linker = lane.linkers[i]
   lane.joiners.make(make_joiner(linker.car,linker:get_y()))
   lane.linkers[i]=nil
  end

  lane.linkers[car_index] = nil
 end

 local function lane_crash_in(lane,car,y)
  local target_car_index = lane:get_car_index_at_y(y)
  if target_car_index <= #lane.linkers then
   if car.is_player then
    --blah()
    move_delay=max_move_delay
   end
   local linker = lane.linkers[target_car_index]
   lane.floaters.make(make_floater(linker.car,linker:get_y()))
   lane:remove_car_at(target_car_index)
  end
  lane.joiners.make(make_joiner(car,y))

  --TODO - handle the case of switching lanes into the front of the herd
 end

 local function lane_find_player_index(lane)
  for i=1,#lane.linkers do
   if lane.linkers[i].car.is_player then
    return i
   end
  end
  return nil
 end

 return function(index, car_count)
  local obj = {
   draw=draw_lane,
   update=update_lane,
   linkers={},
   offset=(rnd(2)-1)*offset_threshold,
   index=index,
   v=rnd(max_velocity - min_velocity)+min_velocity,
   get_tail_y=get_tail_y,
   append_car=lane_append_car,
   get_car_index_at_y=get_car_index_at_y,
   crash_in=lane_crash_in,
   try_lane_switch_from_neighbor=try_lane_switch_from_neighbor,
   has_joiners=lane_has_joiners,
   find_player_index=lane_find_player_index,
   remove_car_at=lane_remove_car_at,
   joiners=make_pool(),
   floaters=make_pool()
  }
  if (rnd(1) > .5) then
   obj.v = -obj.v
  end
  for i=1,car_count do
   obj:append_car(make_car())
  end
  return obj
 end
end)()
-- end ext

-- start ext ./police.lua
police = {}
police = (function()
 local function check_police_in_lane_at_y(lane,y)
  target_index = lane:get_car_index_at_y(y)
  if target_index > 0 and target_index < #lane.linkers and lane.linkers[target_index].car.is_police then
   lost=true
   lane.linkers[target_index].car.arresting=true
  end
 end

 local function check_police_in_lane_for_car_at_y(lane,y)
  check_police_in_lane_at_y(lane,y+2)
  check_police_in_lane_at_y(lane,y+6)
  lane.joiners:each(function(j)
   if j.car.is_police and abs(j.y - y) <= 4 then
    lost=true
    j.car.arresting=true
   end
  end)
 end

 local function check_police_next_to_player()
  local p = get_player_linker()

  if p then
   if p.car_index > 1 and p.lane.linkers[p.car_index-1].car.is_police then
    lost=true
    p.lane.linkers[p.car_index-1].car.arresting=true
   elseif p.car_index < #p.lane.linkers and p.lane.linkers[p.car_index+1].car.is_police then
    lost=true
    p.lane.linkers[p.car_index+1].car.arresting=true
   end
  end

  p = p or get_player_joiner()
  local y = p:get_y()
  if player_lane > 1 then
   check_police_in_lane_for_car_at_y(lanes[player_lane-1],y)
  end
  if player_lane < 15 then
   check_police_in_lane_for_car_at_y(lanes[player_lane+1],y)
  end
 end

 local function update()
  check_police_next_to_player()

  police.cars:each(function(c)
   if not lost or c.arresting == true then
    if not c.delay or c.delay <= 0 then
     local swp = c.color_map[2]
     c.color_map[2] = c.color_map[3]
     c.color_map[3] = swp
     c.primary_color=6
     c.delay = 15
    end
    c.delay-=1
   end
  end)
 end

 local function make()
  if police.cars:count() < 60 then
   local car = make_car()
   car.color_map = {}
   car.color_map[2] = 8
   car.color_map[3] = 12
   car.sprite_id=9
   car.is_police=true
   police.cars.make(car)
   local lane=lanes[ceil(rnd(15))]
   local y=max(camera_y+150,lane:get_tail_y())
   if lane.joiners:is_any() then
    y = max(y,lane.joiners:max('y')+car_space_height)
   end
   lane.joiners.make(make_joiner(car,y))
  end
 end

 return {
  cars=make_pool(),
  update=update,
  make=make
 }
end)()
-- end ext

-- start ext ./main.lua
car_space_height = 9
crash_height = 8

function _init()
 ground_offset=0
 lanes={}
 update_camera_y(400)
 is_intro=true

 for i=1,15 do
  add(lanes,make_lane(i,40))
 end

 player_car = make_car()
 player_car.is_player = true
 player_car.sprite_id = 7
 player_lane=8

 lanes[player_lane].joiners.make(make_joiner(player_car,550))
end

function update_camera_y(new_y)
 camera_y = new_y
 --camera(0,new_y)
end

make_car = (function()
 local function draw_car(car,x,y)
  pal(8,car.primary_color)
  pal(9,car.secondary_color)
  if car.color_map then
   for k,v in pairs(car.color_map) do
    pal(k,v)
   end
  end
  spr(car.sprite_id,x,y-camera_y)
 end

 local function update_car(car)

 end

 local primary_colors = {3,4,8,9,10,11,13,14,15}
 local secondary_colors = {5,5,2,4,9,3,5,13,9}

 return function()
  local color_index = ceil(rnd(#primary_colors))
  local obj = {
   draw=draw_car,
   primary_color=primary_colors[color_index],
   secondary_color=secondary_colors[color_index],
   update=update_car,
   color_map=false,
   sprite_id=6
  }
  return obj
 end
end)()

function lane_index_to_car_x(index)
 return index*8-4
end

make_joiner = (function()
 local speed=.7

 local function update_joiner(joiner, lane)
  joiner.y-=speed
  if lane:get_tail_y() >= joiner.y then
   lane:append_car(joiner.car)
   joiner:kill()
   return
  end
  if joiner.car.is_player then
   return
  end

  local is_crashed = false
  lane.floaters:each(function(f)
   if abs(joiner.y-f.y) <= crash_height then
    is_crashed = true
   end
  end)
  if is_crashed then
   lane.floaters.make(make_floater(joiner.car,joiner.y))
   joiner:kill()
  end
 end

 local function draw_joiner(joiner, lane)
  joiner.car:draw(lane_index_to_car_x(lane.index),joiner.y)
 end

 local function joiner_get_y(joiner)
  return joiner.y
 end

 return function(car,y)
  local obj = {
   y=y,
   car=car,
   get_y=joiner_get_y,
   update=update_joiner,
   draw=draw_joiner
  }
  return obj
 end
end)()

make_floater = (function()
 local speed=1

 local function update_floater(floater,lane)
  floater.y+=speed
  if floater.y > camera_y+128 then
   if floater.car.alive then
    floater.car:kill()
   end
   floater:kill()
   return
  end

  if lane:get_tail_y() > floater.y and floater.y >= lane.offset then

   local target_car_index = lane:get_car_index_at_y(floater.y+crash_height)
   if target_car_index <= #lane.linkers then
    local linker = lane.linkers[target_car_index]
    if not linker.car.is_player then
     printh("test")
     printh(floater.y)
     lane.floaters.make(make_floater(linker.car,linker:get_y()))
     lane:remove_car_at(target_car_index)
    end
   end
  end
 end

 local function draw_floater(floater,lane)
  floater.car:draw(lane_index_to_car_x(lane.index),floater.y)
 end

 local function floater_get_y(floater)
  return floater.y
 end

 return function(car,y)
  local obj = {
   y=y,
   car=car,
   get_y=floater_get_y,
   update=update_floater,
   draw=draw_floater
  }
  car.sprite_id=8
  return obj
 end
end)()

function get_player_linker()
 local player_index = lanes[player_lane]:find_player_index()
 if player_index then
  return lanes[player_lane].linkers[player_index]
 else
  return nil
 end
end

function get_player_joiner()
 local joiner
 lanes[player_lane].joiners:each(function(j)
  if j.car.is_player then
   joiner = j
  end
 end)

 return joiner
end

function get_player_manager()
 return get_player_linker() or get_player_joiner()
end

function move_player(lane_offset)
 local player_linker = get_player_linker()

 if player_linker then
  lanes[player_lane+lane_offset]:crash_in(player_car,player_linker:get_y())
  lanes[player_lane]:remove_car_at(player_linker.car_index)
 else
  local player_joiner = get_player_joiner()
  lanes[player_lane+lane_offset]:crash_in(player_car,player_joiner:get_y())
  player_joiner:kill()
 end
 player_lane+=lane_offset
end

max_move_delay=60
function can_move()
 if move_delay and move_delay > 0 then
  move_delay-=1
  return false
 end
 return true
end

function _update60()
 police.update()

 if lost then
  return
 end

 ground_offset+=1
 if ground_offset >= 8 then
  ground_offset = 0
 end

 for lane in all(lanes) do lane:update() end

 if can_move() then
  if btnp(0) and player_lane > 1 then
   move_player(-1)
  elseif btnp(1) and player_lane < #lanes then
   move_player(1)
  end
 end

 -- attempt ai lane switches
 for i=1,#lanes-1 do
  lanes[i]:try_lane_switch_from_neighbor(lanes[i+1])
  lanes[i+1]:try_lane_switch_from_neighbor(lanes[i])
 end

 if is_intro and get_player_manager():get_y()-50 < camera_y then
  is_intro = false
 end

 if not is_intro then
  police.make()
  update_camera_y(get_player_manager():get_y()-50)
 end
end

function _draw()
 cls()
 for roadx=0,13 do
  for roady=-1,16 do
   spr(5,roadx*8+4,-camera_y%8+roady*8+ground_offset)
  end
 end
 for lane in all(lanes) do lane:draw() end
 line(3,0,3,127,10)
 line(123,0,123,127,10)
 if lost then
  rectfill(48,27,78,39,1)
  rect(49,28,77,38,7)
  print("busted",52,31,7)
 end
end
-- end ext
__gfx__
0000000000888800000008888880000000000000000000000088800000676000c000000000757000000000000000000000000000000000000000000000000000
00000000c888888c0c828888888828c00000000000000000098889000676760000880c0005757500000000000000000000000000000000000000000000000000
007007000c8888c00028888888888200000000000000000789ccc98076ccc67008c0800075666570000000000000000000000000000000000000000000000000
000770000c8888c002c8888888888c2000888800000000000c888c000c767c0000880800222c3330000000000000000000000000000000000000000000000000
0007700008cccc8002c8888888888c2008888880000000000c888c000c676c000c8880c022273330000000000000000000000000000000000000000000000000
0070070008cccc8002c8888888888c20088888800000000709888900067676000888880005757500000000000000000000000000000000000000000000000000
000000000887788002c8888888888c20088888800000000709ccc90006ccc60008c0080c05666500000000000000000000000000000000000000000000000000
00000000050000500288cccccccc882088cccc880000000709888900067676000888880005757500000000000000000000000000000000000000000000000000
0000000000888800088cccccccccc8800c8888c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000888800088cccccccccc8800c8888c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000088cc8800888cccccccc88800c8888c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000c88c000888888888888880088888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000c88c00088888777788888008cccc800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000888800008888777788880008cccc800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000008cc8000022222222222200088778800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000008888000065000000005600050000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888000008880000088800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888800088888000888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88ccc88788ccc8878888888770000007000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c888c070c888c0708ccc80770000007000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c888c000c888c000c888c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888800088888000c888c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08ccc80708ccc80708ccc80770000007000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888807088888070888880770000007000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888000008880000088800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888800088888000888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88ccc88788ccc88788ccc88770000007700000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c888c070c888c070c888c0770000007700000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c888c000c888c000c888c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888800088888000888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08ccc80708ccc80708ccc80770000007700000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888807088888070888880770000007700000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
