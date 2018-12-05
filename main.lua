-- START LIB
function _init()
  ground_offset=0
  lanes={}
  joiners=make_pool()
  floaters=make_pool()
  update_camera_y(400)
  is_intro=true

  for i=1,15 do
    add(lanes,make_lane(i,40))
  end

  player_car = make_car()
  player_car.sprite_id = 7
  player_lane=8

  joiners.make(make_joiner(player_car,player_lane,550))
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

  local function update_joiner(joiner)
    joiner.y-=speed
    if lanes[joiner.lane_index]:get_tail_y() >= joiner.y then
      lanes[joiner.lane_index]:append_car(joiner.car)
      joiner:kill()
    end
  end

  local function draw_joiner(joiner)
    joiner.car:draw(lane_index_to_car_x(joiner.lane_index),joiner.y)
  end

  local function joiner_renderer_get_y(renderer)
    return renderer.joiner.y
  end

  return function(car,lane_index,y)
    local obj = {
      lane_index=lane_index,
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

  local function update_floater(floater)
    floater.y+=speed
    if floater.y > camera_y+128 then
      floater:kill()
    end
  end

  local function draw_floater(floater)
    floater.car:draw(lane_index_to_car_x(floater.lane_index),floater.y)
  end

  local function floater_renderer_get_y(renderer)
    return renderer.floater.y
  end

  return function(car,lane_index,y)
    local obj = {
      lane_index=lane_index,
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
  joiners:each(function(j)
    j:update()
  end)
  floaters:each(function(f)
    f:update()
  end)

  if btnp(0) and player_lane > 1 then
    lanes[player_lane].cars[#lanes[player_lane].cars] = nil
    lanes[player_lane-1]:crash_in(player_car)
    player_lane-=1
  elseif btnp(1) and player_lane < #lanes then
    lanes[player_lane].cars[#lanes[player_lane].cars] = nil
    lanes[player_lane+1]:crash_in(player_car)
    player_lane+=1
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
  joiners:each(function(j)
    j:draw()
  end)
  floaters:each(function(f)
    f:draw()
  end)
  line(3,camera_y,3,camera_y+127,10)
  line(123,camera_y,123,camera_y+127,10)
end
-- END LIB
