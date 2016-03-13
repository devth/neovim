-- Uses :term as a way to send keys and assert screen state.
local helpers = require('test.functional.helpers')
local thelpers = require('test.functional.tui.helpers')
local feed = thelpers.feed_data
local execute = helpers.execute
local nvim_dir = helpers.nvim_dir

describe('tui paste', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
    -- right now pasting can be really slow in the TUI, especially in ASAN.

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

  it('bracketed paste sequence raises PastePre, PastePost', function()
    feed('i\x1b[200~')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      -- INSERT (paste) --                              |
      -- TERMINAL --                                    |
    ]])
    feed('pasted from terminal')
    screen:expect([[
      pasted from terminal{1: }                             |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT (paste) --                              |
      -- TERMINAL --                                    |
    ]])
    feed('\x1b[201~')
    screen:expect([[
      pasted from terminal{1: }                             |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)
end)

describe('tui with non-tty file descriptors', function()
  before_each(helpers.clear)

  after_each(function()
    os.remove('testF') -- ensure test file is removed
  end)

  it('can handle pipes as stdout and stderr', function()
    local screen = thelpers.screen_setup(0, '"'..helpers.nvim_prog..' -u NONE -i NONE --cmd \'set noswapfile\' --cmd \'normal iabc\' > /dev/null 2>&1 && cat testF && rm testF"')
    screen:set_default_attr_ids({})
    screen:set_default_attr_ignore(true)
    feed(':w testF\n:q\n')
    screen:expect([[
      :w testF                                          |
      :q                                                |
      abc                                               |
                                                        |
      [Process exited 0]                                |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)
end)

describe('tui focus event handling', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
    execute('autocmd FocusGained * echo "gained"')
    execute('autocmd FocusLost * echo "lost"')
  end)

  it('can handle focus events in normal mode', function()
    feed('\x1b[I')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      gained                                            |
      -- TERMINAL --                                    |
    ]])

    feed('\x1b[O')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      lost                                              |
      -- TERMINAL --                                    |
    ]])
  end)

  it('can handle focus events in insert mode', function()
    execute('set noshowmode')
    feed('i')
    feed('\x1b[I')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      gained                                            |
      -- TERMINAL --                                    |
    ]])
    feed('\x1b[O')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      lost                                              |
      -- TERMINAL --                                    |
    ]])
  end)

  it('can handle focus events in cmdline mode', function()
    feed(':')
    feed('\x1b[I')
    screen:expect([[
                                                        |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      g{1:a}ined                                            |
      -- TERMINAL --                                    |
    ]])
    feed('\x1b[O')
    screen:expect([[
                                                        |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      l{1:o}st                                              |
      -- TERMINAL --                                    |
    ]])
  end)

  it('can handle focus events in terminal mode', function()
    execute('set shell='..nvim_dir..'/shell-test')
    execute('set laststatus=0')
    execute('set noshowmode')
    execute('terminal')
    feed('\x1b[I')
    screen:expect([[
      ready $                                           |
      [Process exited 0]{1: }                               |
                                                        |
                                                        |
                                                        |
      gained                                            |
      -- TERMINAL --                                    |
    ]])
   feed('\x1b[O')
    screen:expect([[
      ready $                                           |
      [Process exited 0]{1: }                               |
                                                        |
                                                        |
                                                        |
      lost                                              |
      -- TERMINAL --                                    |
    ]])
  end)
end)
