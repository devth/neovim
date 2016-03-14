-- TUI tests
local helpers = require('test.functional.helpers')
local child_tui = require('test.functional.tui.child_session')
local feed_tui = child_tui.feed_data
local execute = helpers.execute
local nvim_dir = helpers.nvim_dir

describe('tui', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = child_tui.screen_setup(0, '["'..helpers.nvim_prog..
      '", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
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

  it('accepts basic utf-8 input', function()
    feed_tui('iabc\ntest1\ntest2')
    screen:expect([[
      abc                                               |
      test1                                             |
      test2{1: }                                            |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
    feed_tui('\027')
    screen:expect([[
      abc                                               |
      test1                                             |
      test{1:2}                                             |
      ~                                                 |
      [No Name] [+]                                     |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  it('interprets leading <Esc> byte as ALT modifier in normal-mode', function()
    local keys = 'dfghjkl'
    for c in keys:gmatch('.') do
      execute('nnoremap <a-'..c..'> ialt-'..c..'<cr><esc>')
      feed_tui('\027'..c)
    end
    screen:expect([[
      alt-j                                             |
      alt-k                                             |
      alt-l                                             |
      {1: }                                                 |
      [No Name] [+]                                     |
                                                        |
      -- TERMINAL --                                    |
    ]])
    feed_tui('gg')
    screen:expect([[
      {1:a}lt-d                                             |
      alt-f                                             |
      alt-g                                             |
      alt-h                                             |
      [No Name] [+]                                     |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  it('does not mangle unmapped ALT-key chord', function()
    -- Vim represents ALT/META by setting the "high bit" of the modified key;
    -- we do _not_. #3982
    --
    -- Example: for input ALT+j:
    --    * Vim (Nvim prior to #3982) sets high-bit, inserts "ê".
    --    * Nvim (after #3982) inserts "j".
    feed_tui('i\027j')
    screen:expect([[
      j{1: }                                                |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)

  it('accepts ascii control sequences', function()
    feed_tui('i')
    feed_tui('\022\007') -- ctrl+g
    feed_tui('\022\022') -- ctrl+v
    feed_tui('\022\013') -- ctrl+m
    screen:expect([[
    {3:^G^V^M}{1: }                                           |
    ~                                                 |
    ~                                                 |
    ~                                                 |
    [No Name] [+]                                     |
    -- INSERT --                                      |
    -- TERMINAL --                                    |
    ]], {[1] = {reverse = true}, [2] = {background = 11}, [3] = {foreground = 4}})
  end)
end)

describe('tui with non-tty file descriptors', function()
  before_each(helpers.clear)

  after_each(function()
    os.remove('testF') -- ensure test file is removed
  end)

  it('can handle pipes as stdout and stderr', function()
    local screen = child_tui.screen_setup(0, '"'..helpers.nvim_prog..
      ' -u NONE -i NONE --cmd \'set noswapfile\' --cmd \'normal iabc\' > /dev/null 2>&1 && cat testF && rm testF"')
    screen:set_default_attr_ids({})
    screen:set_default_attr_ignore(true)
    feed_tui(':w testF\n:q\n')
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
    screen = child_tui.screen_setup(0, '["'..helpers.nvim_prog..
      '", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
    execute('autocmd FocusGained * echo "gained"')
    execute('autocmd FocusLost * echo "lost"')
  end)

  it('can handle focus events in normal mode', function()
    feed_tui('\027[I')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      gained                                            |
      -- TERMINAL --                                    |
    ]])

    feed_tui('\027[O')
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
    feed_tui('i')
    feed_tui('\027[I')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      gained                                            |
      -- TERMINAL --                                    |
    ]])
    feed_tui('\027[O')
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
    feed_tui(':')
    feed_tui('\027[I')
    screen:expect([[
                                                        |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      g{1:a}ined                                            |
      -- TERMINAL --                                    |
    ]])
    feed_tui('\027[O')
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
    feed_tui('\027[I')
    screen:expect([[
      ready $                                           |
      [Process exited 0]{1: }                               |
                                                        |
                                                        |
                                                        |
      gained                                            |
      -- TERMINAL --                                    |
    ]])
   feed_tui('\027[O')
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
