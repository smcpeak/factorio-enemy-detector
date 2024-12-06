-- lua_util.lua
-- General-purpose Lua utilities.


-- Remove elements of `array` for which `keepFn` returns false.
--
-- Based on https://stackoverflow.com/a/53038524/2659307.
--
function filter_array(array, keepFn)
  local next_write_index = 1;
  local last_index = #array;

  for next_read_index = 1, last_index do
    local element = array[next_read_index];
    if (keepFn(element)) then
      if (next_write_index ~= next_read_index) then
        -- Compact the retained elements.
        array[next_write_index] = element;
        array[next_read_index] = nil;
      end;

      next_write_index = next_write_index + 1;

    else
      array[next_read_index] = nil;

    end;
  end;
end;


-- Remove `element` from `array` (if it is present).
function remove_element_from_array(array, element)
  filter_array(array, function(e)
    return e ~= element;
  end);
end;


-- Return -1/0/+1 depending on how `n1` compares to `n2`.
function compare_numbers(n1, n2)
  if (n1 < n2) then
    return -1;
  end;

  if (n1 > n2) then
    return 1;
  end;

  return 0;
end;


-- EOF
