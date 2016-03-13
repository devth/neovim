local helpers = require('test.functional.helpers')
local execute = helpers.execute
local nvim_dir = helpers.nvim_dir
local eval = helpers.eval
local eq = helpers.eq
-- Uses the builtin terminal emulator to send raw input.
local TUI = require('test.functional.tui.helpers')
local tui_input = TUI.feed_data

describe('tui paste', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = TUI.screen_setup(0, '["'..helpers.nvim_prog..
      '", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')

    -- Pasting can be really slow in the TUI, especially in ASAN.
    -- TODO
    -- screen.timeout = 60000
    screen.timeout = 5000
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  after_each(function()
    screen:detach()
  end)

  -- XXX: error when pasting into 'nomodifiable' buffer:
  --      [error @ do_put:2656] 17043 - Failed to save undo information
  it("handles 'nomodifiable' buffer gracefully", function()
  end)

  -- it('bracketed paste sequence raises PastePre, PastePost', function()
  --   eq(0, eval("exists('g:_pastepre') || exists('g:_pastepost')")) -- sanity
  --   execute('autocmd PastePre  let g:_pastepre=1')
  --   execute('autocmd PastePost let g:_pastepost=1')
  --   tui_input('i\x1b[200~')

  --   tui_input('\x1b[201~')
  --   screen:expect([[
  --     pasted from terminal{1: }                             |
  --     ~                                                 |
  --     ~                                                 |
  --     ~                                                 |
  --     [No Name] [+]                                     |
  --     -- INSERT --                                      |
  --     -- TERMINAL --                                    |
  --   ]])
  -- end)

  it('bracketed paste sequence raises PastePre, PastePost', function()
    eq(0, eval("exists('g:_pastepre') || exists('g:_pastepost')")) -- sanity

    execute('autocmd PastePre  * let g:_pastepre=1')
    execute('autocmd PastePost * let g:_pastepost=1')

    tui_input('i\x1b[200~')
    eq(0, eval("exists('g:_pastepost')"))
    eq(1, eval("g:_pastepre"))

    tui_input('\x1b[201~')
    eq(1, eval("g:_pastepost"))
  end)
end)

