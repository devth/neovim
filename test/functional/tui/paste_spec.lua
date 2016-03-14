-- TUI tests for "bracketed paste" mode.
-- http://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Bracketed-Paste-Mode
local helpers = require('test.functional.helpers')
local child_tui = require('test.functional.tui.child_session')
local execute = helpers.execute
local nvim_dir = helpers.nvim_dir
local eval = helpers.eval
local eq = helpers.eq
local feed_tui = child_tui.feed_data

describe('tui paste', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = child_tui.screen_setup(0, '["'..helpers.nvim_prog..
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

  local function setup_harness()
    -- Delete the default PastePre/PastePost autocmds.
    feed_tui(":autocmd! PastePre,PastePost\n")

    -- Set up test handlers.
    feed_tui(":autocmd PastePre * "..
      "call feedkeys('iPastePre mode:'.mode(),'n')\n")
    feed_tui(":autocmd PastePost * "..
      "call feedkeys('PastePost mode:'.mode(),'n')\n")
  end

  it('handles long bursts of input', function()
    execute('set ruler')
    local t = {}
    for i = 1, 3000 do
      t[i] = 'item ' .. tostring(i)
    end
    feed_tui('i\027[200~')
    feed_tui(table.concat(t, '\n'))
    feed_tui('\027[201~')
    screen:expect([[
      item 2997                                         |
      item 2998                                         |
      item 2999                                         |
      item 3000{1: }                                        |
      [No Name] [+]                   3000,10        Bot|
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)

  it('raises PastePre, PastePost', function()
    setup_harness()

    -- Send the "start paste" sequence.
    feed_tui("\027[200~")
    feed_tui("\npasted from terminal (1)\npasted from terminal (2)\n")
    -- Send the "stop paste" sequence.
    feed_tui("\027[201~")

    screen:expect([[
      PastePre mode:n                                   |
      pasted from terminal (1)                          |
      pasted from terminal (2)                          |
      PastePost mode:i{1: }                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)

  it('ignores spurious "start paste" sequence', function()
    setup_harness()
    -- If multiple "start paste" sequences are sent without a corresponding
    -- "stop paste" sequence, only the first occurrence should be recognized.

    -- Send the "start paste" sequence.
    feed_tui("\027[200~")
    feed_tui("\027[200~")
    feed_tui("\npasted from terminal (1)\npasted from terminal (2)\n")
    -- Send the "stop paste" sequence.
    feed_tui("\027[201~")

    screen:expect([[
      PastePre mode:n                                   |
      pasted from terminal (1)                          |
      pasted from terminal (2)                          |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)

  -- TODO
  it('handles missing "stop paste" sequence', function()
  end)

  -- TODO: error when pasting into 'nomodifiable' buffer:
  --      [error @ do_put:2656] 17043 - Failed to save undo information
  it("handles 'nomodifiable' buffer gracefully", function()
  end)

end)

