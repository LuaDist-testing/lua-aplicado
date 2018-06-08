--------------------------------------------------------------------------------
-- lj2_chunk_inspector.lua: basic Lua chunk inspector based on LJ2 API
--------------------------------------------------------------------------------

local string_sub = string.sub

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments,
      eat_true
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local running_under_luajit
      = import 'lua-aplicado/luajit2.lua'
      {
        'running_under_luajit'
      }

--------------------------------------------------------------------------------

if not running_under_luajit() then
  error("Sorry, this module supports LuaJIT 2 only")
end

--------------------------------------------------------------------------------

-- Doing require this late to allow the LJ2 check above.
local jutil = require 'jit.util'
local bcnames = require 'jit.vmdef'.bcnames
local bit = require 'bit'

--------------------------------------------------------------------------------

local make_chunk_inspector
do
  -- Private function
  local update_info = function(self)
    method_arguments(self)

    self.info_ = self.info_ or assert(
        jutil.funcinfo(self.chunk_),
        "not a Lua function"
      )
  end

  local get_num_upvalues = function(self)
    method_arguments(self)

    update_info(self)

    return self.info_.upvalues
  end

  -- Private function
  -- Based on
  -- http://lua-users.org/lists/lua-l/2009-11/msg00535.html
  local update_globals_lists = function(self)
    method_arguments(self)

    if self.gets_ ~= nil then
      assert(self.sets_ ~= nil)
    else
      assert(self.sets_ == nil)

      self.gets_, self.sets_ = { }, { }

      update_info(self)

      local info = self.info_
      local chunk = self.chunk_

      for i = 1, info.bytecodes do
        local ins, m = jutil.funcbc(chunk, i)
        if not ins then
          break -- TODO: ?!
        end

        local oidx = 6 * bit.band(ins, 0xff)
        local opcode = string_sub(bcnames, oidx + 1, oidx + 6)
        if opcode == "GGET  " or opcode == "GSET  " then
          local d = bit.rshift(ins, 16)
          local name = jutil.funck(chunk, -d - 1)

          local list = (opcode == "GGET  ") and self.gets_ or self.sets_

          local global = list[name]
          if not global then
            global = { }
            list[name] = global
          end

          global[#global + 1] =
          {
            line = jutil.funcinfo(chunk, i).currentline;
            source = info.source;
          }
        end
      end
    end
  end

  local list_gets = function(self)
    method_arguments(self)

    update_globals_lists(self)

    return assert(self.gets_)
  end

  local list_sets = function(self)
    method_arguments(self)

    update_globals_lists(self)

    return assert(self.sets_)
  end

  make_chunk_inspector = function(chunk)
    arguments(
        "function", chunk
      )

    return
    {
      get_num_upvalues = get_num_upvalues;
      list_gets = list_gets;
      list_sets = list_sets;
      --
      chunk_ = chunk;
      info_ = nil;
      gets_ = nil;
      sets_ = nil;
    }
  end
end

--------------------------------------------------------------------------------

return
{
  make_chunk_inspector = make_chunk_inspector;
}
