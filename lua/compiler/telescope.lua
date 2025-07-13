--- ### Frontend for compiler.nvim using vim.ui.select

local M = {}

function M.show()
  -- If working directory is home, don't open picker.
  if vim.loop.os_homedir() == vim.loop.cwd() then
    vim.notify("You must :cd your project dir first.\nHome is not allowed as working dir.", vim.log.levels.WARN, {
      title = "Compiler.nvim"
    })
    return
  end

  -- Dependencies
  local utils = require("compiler.utils")
  local utils_bau = require("compiler.utils-bau")

  local buffer = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = buffer })

  -- POPULATE
  -- ========================================================================

  -- Programatically require the backend for the current language.
  local language = utils.require_language(filetype)

  -- On unsupported languages, default to make.
  if not language then language = utils.require_language("make") or {} end

  -- Also show options discovered on Makefile, Cmake... and other bau.
  if not language.bau_added then
    language.bau_added = true
    local bau_opts = utils_bau.get_bau_opts()

    -- Insert a separator on picker for every bau.
    local last_bau_value = nil
    for _, item in ipairs(bau_opts) do
      if last_bau_value ~= item.bau then
        table.insert(language.options, { text = "", value = "separator" })
        last_bau_value = item.bau
      end
      table.insert(language.options, item)
    end
  end

  -- Add numbers in front of the options to display.
  local index_counter = 0
  for _, option in ipairs(language.options) do
    if option.value ~= "separator" then
      index_counter = index_counter + 1
      option.text = index_counter .. " - " .. option.text
    end
  end

  -- RUN ACTION ON SELECTED
  -- ========================================================================

  --- On option selected → Run action depending of the language.
  local function on_option_selected(selection)
    if not selection or selection.value == "separator" then return end

    -- Do the selected option belong to a build automation utility?
    local bau = nil
    for _, value in ipairs(language.options) do
      if value.text == selection.text then
        bau = value.bau
      end
    end

    if bau then -- call the bau backend.
      local bau_mod = utils_bau.require_bau(bau)
      if bau_mod then bau_mod.action(selection.value) end
      _G.compiler_redo_selection = nil
      _G.compiler_redo_bau_selection = selection.value
      _G.compiler_redo_bau = bau_mod
    else -- call the language backend.
      language.action(selection.value)
      _G.compiler_redo_selection = selection.value
      _G.compiler_redo_filetype = filetype
      _G.compiler_redo_bau_selection = nil
      _G.compiler_redo_bau = nil
    end
  end

  -- SHOW VIM.UI.SELECT
  -- ========================================================================
  local function open_picker()
    local entries = {}
    for _, option in ipairs(language.options) do
      if option.value == "separator" then
        table.insert(entries, { text = "--------------------", value = "separator" })
      else
        table.insert(entries, option)
      end
    end

    vim.ui.select(entries, {
      prompt = "Compiler Options",
      format_item = function(item)
        return item.text
      end,
    }, function(choice)
      on_option_selected(choice)
    end)
  end

  open_picker() -- Entry point
end

return M
