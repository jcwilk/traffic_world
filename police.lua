-- START LIB
police = {}
police = (function()
  local function update()
    police.cars:each(function(c)
      if not c.delay or c.delay <= 0 then
        local swp = c.color_map[2]
        c.color_map[2] = c.color_map[3]
        c.color_map[3] = swp
        c.delay = 20
      end
      c.delay-=1
    end)
  end

  local function make()
    local car = make_car()
    car.color_map = {}
    car.color_map[2] = 8
    car.color_map[3] = 12
    car.sprite_id=9
    police.cars.make(car)
    lanes[5].joiners.make(make_joiner(car,camera_y+150))
  end

  return {
    cars=make_pool(),
    update=update,
    make=make
  }
end)()
-- END LIB
