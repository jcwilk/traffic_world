-- START LIB
function _init()
  ground_offset=0
  lanes={}
  player_offset=-400

  for i=1,15 do
    add(lanes,make_lane(i,50))
  end
end

make_car = (function()
  local function draw_car(car,x,y)
    pal(8,car.color)
    spr(6,x,y)
  end

  local function update_car(car)

  end

  local allowed_colors = {3,4,6,7,8,9,10,11,13,14,15}

  return function()
    local obj = {
      draw=draw_car,
      lane=flr(rnd(15)),
      color=allowed_colors[ceil(rnd(#allowed_colors))],
      y=flr(rnd(128))-4,
      update=update_car
    }
    return obj
  end
end)()

make_lane = (function()
  local car_space_height = 9
  local offset_threshold = 30
  local min_velocity = .25
  local max_velocity = .5

  local function index_to_car_x(index)
    return index*8-4
  end

  local function draw_lane(lane,player_offset)
    local car
    local total_offset = player_offset + lane.offset
    local first_to_draw = flr(-total_offset / car_space_height)
    local last_to_draw = first_to_draw + ceil(128 / car_space_height) + 1

    if #lane.cars > 0 and last_to_draw >= 1 and first_to_draw <= #lane.cars then
      first_to_draw = max(1,first_to_draw)
      last_to_draw = min(#lane.cars,last_to_draw)

      local current_y = total_offset + (first_to_draw-1) * car_space_height
      for i=first_to_draw,last_to_draw do
        lane.cars[i]:draw(index_to_car_x(lane.index),current_y)
        current_y+= car_space_height
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

  return function(index, car_count)
    local obj = {
      draw=draw_lane,
      update=update_lane,
      cars={},
      offset=(rnd(2)-1)*offset_threshold,
      index=index,
      v=rnd(max_velocity - min_velocity)+min_velocity
    }
    if (rnd(1) > .5) then
      obj.v = -obj.v
    end
    for i=1,car_count do
      add(obj.cars,make_car())
    end
    return obj
  end
end)()

function _update60()
  ground_offset+=1
  if ground_offset >= 8 then
    ground_offset = 0
  end

  for lane in all(lanes) do lane:update() end

  player_offset+=.1
end

function _draw()
  cls()
  for roadx=0,13 do
    for roady=-1,15 do
      spr(5,roadx*8+4,roady*8+ground_offset)
    end
  end
  for lane in all(lanes) do lane:draw(player_offset) end
  -- for roadx=0,14 do
  --   spr(6,roadx*8+4,10)
  -- end
  line(3,0,3,127,10)
  line(123,0,123,127,10)
end
-- END LIB
