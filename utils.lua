-- START LIB

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

-- END LIB
