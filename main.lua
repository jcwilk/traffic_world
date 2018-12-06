-- START LIB
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

function _update60()
  ground_offset+=1
  if ground_offset >= 8 then
    ground_offset = 0
  end

  for lane in all(lanes) do lane:update() end

  if btnp(0) and player_lane > 1 then
    police.make()
    move_player(-1)
  elseif btnp(1) and player_lane < #lanes then
    move_player(1)
  end

  police.update()

  -- attempt ai lane switches
  for i=1,#lanes-1 do
    lanes[i]:try_lane_switch_from_neighbor(lanes[i+1])
    lanes[i+1]:try_lane_switch_from_neighbor(lanes[i])
  end

  if is_intro and get_player_manager():get_y()-50 < camera_y then
    is_intro = false
  end

  if not is_intro then
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
end
-- END LIB
