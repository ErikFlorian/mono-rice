 local M = {}

function M.setup()
  require('base16-colorscheme').setup({
    base00 = '{{ colors.on_primary_container.default.hex }}',
    base01 = '{{ colors.background.default.hex }}',
    base02 = '{{ colors.surface_container.default.hex }}',
    base03 = '{{ colors.outline.default.hex }}',
    base04 = '{{ colors.on_surface_variant.default.hex }}',
    base05 = '{{ colors.on_surface.default.hex }}',
    base06 = '{{ colors.on_surface.default.hex }}',
    base07 = '{{ colors.on_surface.default.hex }}',
    base08 = '{{ colors.error.default.hex }}',
    base09 = '{{ colors.on_surface_variant.default.hex }}',
    base0A = '{{ colors.on_surface_variant.default.hex }}',
    base0B = '{{ colors.on_surface_variant.default.hex }}',
    base0C = '{{ colors.on_surface_variant.default.hex }}',
    base0D = '{{ colors.on_surface_variant.default.hex }}',
    base0E = '{{ colors.on_surface_variant.default.hex }}',
    base0F = '{{ colors.on_surface.default.hex }}',
  })

  local hi = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- telescope.nvim
  hi('TelescopeNormal',         { fg = '{{ colors.on_surface.default.hex }}',          bg = '{{ colors.on_primary_container.default.hex }}' })
  hi('TelescopeBorder',         { fg = '{{ colors.outline.default.hex }}',             bg = '{{ colors.on_primary_container.default.hex }}' })
  hi('TelescopePromptNormal',   { fg = '{{ colors.on_surface.default.hex }}',          bg = '{{ colors.on_primary_container.default.hex }}' })
  hi('TelescopePromptBorder',   { fg = '{{ colors.outline.default.hex }}',             bg = '{{ colors.on_primary_container.default.hex }}' })
  hi('TelescopePromptPrefix',   { fg = '{{ colors.on_surface_variant.default.hex }}',             bg = '{{ colors.on_primary_container.default.hex }}' })
  hi('TelescopePromptCounter',  { fg = '{{ colors.on_surface_variant.default.hex }}',  bg = '{{ colors.on_primary_container.default.hex }}' })
  hi('TelescopePromptTitle',    { fg = '{{ colors.on_primary_container.default.hex }}',             bg = '{{ colors.on_surface_variant.default.hex }}' })
  hi('TelescopePreviewTitle',   { fg = '{{ colors.on_primary_container.default.hex }}',             bg = '{{ colors.on_surface_variant.default.hex }}' })
  hi('TelescopeResultsTitle',   { fg = '{{ colors.on_primary_container.default.hex }}',             bg = '{{ colors.on_surface_variant.default.hex }}' })
  hi('TelescopeSelection',      { fg = '{{ colors.on_surface.default.hex }}',          bg = '{{ colors.surface_container.default.hex }}' })
  hi('TelescopeSelectionCaret', { fg = '{{ colors.on_surface_variant.default.hex }}',             bg = '{{ colors.surface_container.default.hex }}' })
  hi('TelescopeMatching',       { fg = '{{ colors.on_surface_variant.default.hex }}',             bold = true })

  -- mini.pick
  hi('MiniPickNormal',         { fg = '{{ colors.on_surface.default.hex }}',          bg = '{{ colors.on_primary_container.default.hex }}' })
  hi('MiniPickBorder',         { fg = '{{ colors.outline.default.hex }}',             bg = '{{ colors.on_primary_container.default.hex }}' })
  hi('MiniPickPrompt',   { fg = '{{ colors.on_surface.default.hex }}',          bg = '{{ colors.on_primary_container.default.hex }}' })
  hi('MiniPickPromptPrefix',   { fg = '{{ colors.on_surface_variant.default.hex }}',             bg = '{{ colors.on_primary_container.default.hex }}' })
  hi('MiniPickBorderText',    { fg = '{{ colors.on_primary_container.default.hex }}',             bg = '{{ colors.on_surface_variant.default.hex }}' })
  hi('MiniPickMatchCurrent',      { fg = '{{ colors.on_surface.default.hex }}',          bg = '{{ colors.surface_container.default.hex }}' })
  hi('MiniPickPromptCaret', { fg = '{{ colors.on_surface_variant.default.hex }}',             bg = '{{ colors.surface_container.default.hex }}' })
  hi('MiniPickMatchRanges',       { fg = '{{ colors.on_surface_variant.default.hex }}',             bold = true })
end

-- Register a signal handler for SIGUSR1 (matugen updates).
-- The handler re-requires this module, which re-runs the code below, so the
-- previous handle is stopped first; otherwise handlers double on every signal.
if _G.__matugen_signal then
  _G.__matugen_signal:stop()
  _G.__matugen_signal:close()
end

local signal = vim.uv.new_signal()
_G.__matugen_signal = signal
signal:start(
  'sigusr1',
  vim.schedule_wrap(function()
    package.loaded['matugen'] = nil
    require('matugen').setup()
  end)
)

return M
