-- START LIB
car_space_height = 9

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
    if joiner.car.is_player then
      return
    end

    local is_crashed = false
    lane.floaters:each(function(f)
      if abs(joiner.y-f.y) <= car_space_height-1 then
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

function move_player(lane_offset)
  lanes[player_lane+lane_offset]:crash_in(player_car)

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
  player_lane+=lane_offset
end

function _update60()
  ground_offset+=1
  if ground_offset >= 8 then
    ground_offset = 0
  end

  for lane in all(lanes) do lane:update() end

  if btnp(0) and player_lane > 1 then
    move_player(-1)
  elseif btnp(1) and player_lane < #lanes then
    move_player(1)
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
-- END LIB
