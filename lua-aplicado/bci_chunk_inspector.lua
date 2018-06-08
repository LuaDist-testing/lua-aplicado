--------------------------------------------------------------------------------
-- bci_chunk_inspector.lua: basic Lua chunk inspector based on bci
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

if running_under_luajit() then
  error("Sorry, LuaJIT is not supported by this module")
end

--------------------------------------------------------------------------------

-- Doing require this late to allow the LJ2 check above.
local bci = require 'inspector'

--------------------------------------------------------------------------------

local make_chunk_inspector
do
  -- Private function
  local update_info = function(self)
    method_arguments(self)

    self.info_ = self.info_ or bci.getheader(self.chunk_)
  end

  local get_num_upvalues = function(self)
    method_arguments(self)

    update_info(self)

    return self.info_.upvalues
  end

  -- Private function
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

      for i = 1, info.instructions do
        local line, opcode, a, b, c = bci.getinstruction(chunk, i)

        if opcode == "GETGLOBAL" or opcode == "SETGLOBAL" then
          local name = bci.getconstant(chunk, -b)

          local list = (opcode == "GETGLOBAL") and self.gets_ or self.sets_

          local global = list[name]
          if not global then
            global = { }
            list[name] = global
          end

          global[#global + 1] =
          {
            line = line;
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
