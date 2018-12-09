-- START LIB
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
-- END LIB
