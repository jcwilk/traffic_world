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
 local car_space_height = 9
 local offset_threshold = 30
 local min_velocity = .25
 local max_velocity = .5

 local function draw_lane(lane)
  local car
  local total_offset = lane.offset
  local first_to_draw = flr((camera_y-total_offset) / car_space_height)
  local last_to_draw = first_to_draw + ceil(128 / car_space_height) + 1

  if #lane.cars > 0 and last_to_draw >= 1 and first_to_draw <= #lane.cars then
   first_to_draw = max(1,first_to_draw)
   last_to_draw = min(#lane.cars,last_to_draw)

   for i=first_to_draw,last_to_draw do
    lane.cars[i].renderer:draw()
   end
  end

  lane.joiners:each(function(j)
   j:draw(lane)
  end)
  lane.floaters:each(function(f)
   f:draw(lane)
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

  if target_index > 0 and target_index <= #lane_from.cars then
   local car = lane_from.cars[target_index]
   if car.is_player then
    return
   end

   lane_to:crash_in(car)
   lane_from:remove_car_at(target_index)
  end
 end

 local function get_tail_y(lane)
  return lane.offset + #lane.cars * car_space_height
 end

 local function lane_renderer_draw(renderer)
  renderer.car:draw(lane_index_to_car_x(renderer.lane.index),renderer:get_y())
 end

 local function lane_renderer_get_y(renderer)
  return renderer.lane.offset + (renderer.car_index-1) * car_space_height
 end

 local function make_lane_renderer(lane,car,car_index)
  return {
   lane=lane,
   car=car,
   car_index=car_index,
   draw=lane_renderer_draw,
   get_y=lane_renderer_get_y
  }
 end

 local function lane_append_car(lane,car)
  car.renderer = make_lane_renderer(lane,car,#lane.cars+1)
  add(lane.cars,car)
 end

 local function lane_has_joiners(lane)
  return lane.joiners:is_any()
 end

 local function get_car_index_at_y(lane,y)
  return ceil((y-lane.offset) / car_space_height)
 end

 local function lane_remove_car_at(lane,car_index)
  for i = #lane.cars,car_index+1,-1 do
   car = lane.cars[i]
   lane.joiners.make(make_joiner(car,car.renderer:get_y()))
   lane.cars[i]=nil
  end

  lane.cars[car_index] = nil
 end

 local function lane_crash_in(lane,car)
  local y = car.renderer:get_y()
  local target_car_index = lane:get_car_index_at_y(y)
  if target_car_index <= #lane.cars then
   local car_i
   for i=#lane.cars,target_car_index,-1 do
    car_i = lane.cars[i]
    lane.floaters.make(make_floater(car_i,car_i.renderer:get_y()))
    lane.cars[i] = nil
   end
  end
  lane.joiners.make(make_joiner(car,y))

  --TODO - handle the case of switching lanes into the front of the herd
 end

 local function lane_find_player_index(lane)
  for i=1,#lane.cars do
   if lane.cars[i].is_player then
    return i
   end
  end
  return nil
 end

 return function(index, car_count)
  local obj = {
   draw=draw_lane,
   update=update_lane,
   cars={},
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

-- start ext ./main.lua
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
 camera(0,new_y)
end

make_car = (function()
 local function draw_car(car,x,y)
  pal(8,car.color)
  spr(car.sprite_id,x,y)
 end

 local function update_car(car)

 end

 local allowed_colors = {3,4,8,9,10,11,13,14,15}

 return function()
  local obj = {
   draw=draw_car,
   color=allowed_colors[ceil(rnd(#allowed_colors))],
   update=update_car,
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
  end
 end

 local function draw_joiner(joiner, lane)
  joiner.car:draw(lane_index_to_car_x(lane.index),joiner.y)
 end

 local function joiner_renderer_get_y(renderer)
  return renderer.joiner.y
 end

 return function(car,y)
  local obj = {
   y=y,
   car=car,
   update=update_joiner,
   draw=draw_joiner
  }
  local joiner_renderer = {
   get_y=joiner_renderer_get_y,
   joiner=obj,
   draw=function() end
  }
  car.renderer = joiner_renderer
  return obj
 end
end)()

make_floater = (function()
 local speed=1

 local function update_floater(floater,lane)
  floater.y+=speed
  if floater.y > camera_y+128 then
   floater:kill()
  end
 end

 local function draw_floater(floater,lane)
  floater.car:draw(lane_index_to_car_x(lane.index),floater.y)
 end

 local function floater_renderer_get_y(renderer)
  return renderer.floater.y
 end

 return function(car,y)
  local obj = {
   y=y,
   car=car,
   update=update_floater,
   draw=draw_floater
  }
  local floater_renderer = {
   get_y=floater_renderer_get_y,
   floater=obj
  }
  car.renderer = floater_renderer
  return obj
 end
end)()

function _update60()
 ground_offset+=1
 if ground_offset >= 8 then
  ground_offset = 0
 end

 for lane in all(lanes) do lane:update() end

 if btnp(0) and player_lane > 1 then
  lanes[player_lane-1]:crash_in(player_car) --lanes[player_lane]:find_player_index(),lanes[player_lane])

  local player_car_index = lanes[player_lane]:find_player_index()
  if player_car_index then
   lanes[player_lane]:remove_car_at(player_car_index)
  else
   lanes[player_lane].joiners:each(function(j)
    if j.car.is_player then
     j:kill()
    end
   end)
  end
  player_lane-=1
 elseif btnp(1) and player_lane < #lanes then
  lanes[player_lane+1]:crash_in(player_car)

  local player_car_index = lanes[player_lane]:find_player_index()
  if player_car_index then
   lanes[player_lane]:remove_car_at(player_car_index)
  else
   lanes[player_lane].joiners:each(function(j)
    if j.car.is_player then
     j:kill()
    end
   end)
  end
  player_lane+=1
 end

 -- attempt ai lane switches
 for i=1,#lanes-1 do
  lanes[i]:try_lane_switch_from_neighbor(lanes[i+1])
  lanes[i+1]:try_lane_switch_from_neighbor(lanes[i])
 end

 if is_intro and player_car.renderer:get_y()-50 < camera_y then
  is_intro = false
 end

 if not is_intro then
  update_camera_y(player_car.renderer:get_y()-50)
 end
end

function _draw()
 cls()
 for roadx=0,13 do
  for roady=-1,16 do
   spr(5,roadx*8+4,camera_y-camera_y%8+roady*8+ground_offset)
  end
 end
 for lane in all(lanes) do lane:draw() end
 line(3,camera_y,3,camera_y+127,10)
 line(123,camera_y,123,camera_y+127,10)
end
-- end ext
__gfx__
00000000008888000000088888800000000000000000000000888000007670000000000000000000000000000000000000000000000000000000000000000000
00000000c888888c0c828888888828c0000000000000000008888800067676000000000000000000000000000000000000000000000000000000000000000000
007007000c8888c00028888888888200000000000000000788ccc88076ccc6700000000000000000000000000000000000000000000000000000000000000000
000770000c8888c002c8888888888c2000888800000000000c888c000c767c000000000000000000000000000000000000000000000000000000000000000000
0007700008cccc8002c8888888888c2008888880000000000c888c000c767c000000000000000000000000000000000000000000000000000000000000000000
0070070008cccc8002c8888888888c20088888800000000708888800067676000000000000000000000000000000000000000000000000000000000000000000
000000000887788002c8888888888c20088888800000000708ccc80006ccc6000000000000000000000000000000000000000000000000000000000000000000
00000000050000500288cccccccc882088cccc880000000708888800067676000000000000000000000000000000000000000000000000000000000000000000
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
