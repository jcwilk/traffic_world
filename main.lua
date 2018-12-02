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

local function lane_index_to_car_x(index)
  return index*8-4
end

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
  end

  local function update_lane(lane)
    lane.offset+=lane.v
    if lane.offset > offset_threshold and lane.v > -min_velocity then
      lane.v-= rnd(max_velocity-min_velocity)
    elseif lane.offset < -offset_threshold and lane.v < min_velocity then
      lane.v+= rnd(max_velocity-min_velocity)
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

  return function(index, car_count)
    local obj = {
      draw=draw_lane,
      update=update_lane,
      cars={},
      offset=(rnd(2)-1)*offset_threshold,
      index=index,
      v=rnd(max_velocity - min_velocity)+min_velocity,
      get_tail_y=get_tail_y,
      append_car=lane_append_car
    }
    if (rnd(1) > .5) then
      obj.v = -obj.v
    end
    local car
    for i=1,car_count do
      obj:append_car(make_car())
    end
    return obj
  end
end)()

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
      joiner=obj
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
      get_y=joiner_renderer_get_y,
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
  line(3,camera_y,3,camera_y+127,10)
  line(123,camera_y,123,camera_y+127,10)
end
-- END LIB
