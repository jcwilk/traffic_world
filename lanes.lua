-- START LIB
make_lane = (function()
  local offset_threshold = 30
  local min_velocity = .25
  local max_velocity = .5

  local function draw_lane(lane)
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
      printh(lane.index)
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
-- END LIB
