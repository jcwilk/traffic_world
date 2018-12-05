-- START LIB
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

  local function try_lane_switch_from_neighbors(lane)
    -- local
    -- for i in all({lane.index-1,lane.index+1}) do

    -- end
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

  local function get_car_index_at_y(lane,y)
    return ceil((y-lane.offset) / car_space_height)
  end

  local function lane_crash_in(lane,car)
    local y = car.renderer:get_y()
    local target_car_index = lane:get_car_index_at_y(y)
    if target_car_index <= #lane.cars then
      local car_i
      for i=#lane.cars,target_car_index,-1 do
        car_i = lane.cars[i]
        floaters.make(make_floater(car_i,lane.index,car_i.renderer:get_y()))
        lane.cars[i] = nil
      end
    end
    joiners.make(make_joiner(car,lane.index,y))

    --TODO - handle the case of switching lanes into the front of the herd
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
      crash_in=lane_crash_in
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
-- END LIB
