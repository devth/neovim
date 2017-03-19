local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local feed, clear, nvim = helpers.feed, helpers.clear, helpers.nvim
local command = helpers.command
local wait = helpers.wait
local eval, feed_command, source = helpers.eval, helpers.feed_command, helpers.source
local eq, neq = helpers.eq, helpers.neq
local write_file = helpers.write_file

if helpers.pending_win32(pending) then return end

describe('terminal buffer', function()
  local screen

  before_each(function()
    clear()
    feed_command('set modifiable swapfile undolevels=20')
    wait()
    screen = thelpers.screen_setup()
  end)

  it("defaults to bufhidden=hide", function()
    eq({'terminal', 'hide'}, eval("[&buftype, &bufhidden]"))
  end)

  it("bufhidden=hide", function()
    eq({'terminal', 1}, eval("[&buftype, bufnr('%')]"))
    command('edit buf2')    -- create a normal buffer
    eq({'', 2}, eval("[&buftype, bufnr('%')]"))
    command('buffer #')     -- switch to terminal buffer
    command('set bufhidden=hide')
    command('buffer! #')
    eq({'', 'buf2'}, eval("[&buftype, bufname('%')]"))
    eq({'terminal', 1, 1},
       eval("[getbufvar(1, '&buftype'), bufloaded(1), bufexists(1)]"))
  end)

  it("bufhidden=unload", function()
    eq({'terminal', 1}, eval("[&buftype, bufnr('%')]"))
    command('edit buf2')    -- create a normal buffer
    eq({'', 2}, eval("[&buftype, bufnr('%')]"))
    command('buffer #')     -- switch to terminal buffer
    command('set bufhidden=unload')
    command('buffer! #')
    eq({'', 'buf2'}, eval("[&buftype, bufname('%')]"))
    eq({'terminal', 0, 1},
       eval("[getbufvar(1, '&buftype'), bufloaded(1), bufexists(1)]"))
  end)

  it("bufhidden=delete", function()
    eq({'terminal', 1}, eval("[&buftype, bufnr('%')]"))
    command('edit buf2')    -- create a normal buffer
    eq({'', 2}, eval("[&buftype, bufnr('%')]"))
    command('buffer #')     -- switch to terminal buffer
    command('set bufhidden=delete')
    command('buffer! #')
    eq({'', 'buf2'}, eval("[&buftype, bufname('%')]"))
    eq({'', 0, 1},
       eval("[getbufvar(1, '&buftype'), bufloaded(1), bufexists(1)]"))
  end)

  it("bufhidden=wipe", function()
    eq({'terminal', 1}, eval("[&buftype, bufnr('%')]"))
    command('edit buf2')    -- create a normal buffer
    eq({'', 2}, eval("[&buftype, bufnr('%')]"))
    command('buffer #')     -- switch to terminal buffer
    command('set bufhidden=wipe')
    command('buffer! #')
    eq({'', 'buf2'}, eval("[&buftype, bufname('%')]"))
    eq({'', 0, 0},
       eval("[getbufvar(1, '&buftype'), bufloaded(1), bufexists(1)]"))
  end)

  describe('swap and undo', function()
    before_each(function()
      feed('<c-\\><c-n>')
      screen:expect([[
        tty ready                                         |
        {2:^ }                                                 |
                                                          |
                                                          |
                                                          |
                                                          |
                                                          |
      ]])
    end)

    it('does not create swap files', function()
      local swapfile = nvim('command_output', 'swapname'):gsub('\n', '')
      eq(nil, io.open(swapfile))
    end)

    it('does not create undofiles files', function()
      local undofile = nvim('eval', 'undofile(bufname("%"))')
      eq(nil, io.open(undofile))
    end)
  end)

  it('cannot be modified directly', function()
    feed('<c-\\><c-n>dd')
    screen:expect([[
      tty ready                                         |
      {2:^ }                                                 |
                                                        |
                                                        |
                                                        |
                                                        |
      {8:E21: Cannot make changes, 'modifiable' is off}     |
    ]])
  end)

  it('sends data to the terminal when the "put" operator is used', function()
    feed('<c-\\><c-n>gg"ayj')
    feed_command('let @a = "appended " . @a')
    feed('"ap"ap')
    screen:expect([[
      ^tty ready                                         |
      appended tty ready                                |
      appended tty ready                                |
      {2: }                                                 |
                                                        |
                                                        |
      :let @a = "appended " . @a                        |
    ]])
    -- operator count is also taken into consideration
    feed('3"ap')
    screen:expect([[
      ^tty ready                                         |
      appended tty ready                                |
      appended tty ready                                |
      appended tty ready                                |
      appended tty ready                                |
      appended tty ready                                |
      :let @a = "appended " . @a                        |
    ]])
  end)

  it('sends data to the terminal when the ":put" command is used', function()
    feed('<c-\\><c-n>gg"ayj')
    feed_command('let @a = "appended " . @a')
    feed_command('put a')
    screen:expect([[
      ^tty ready                                         |
      appended tty ready                                |
      {2: }                                                 |
                                                        |
                                                        |
                                                        |
      :put a                                            |
    ]])
    -- line argument is only used to move the cursor
    feed_command('6put a')
    screen:expect([[
      tty ready                                         |
      appended tty ready                                |
      appended tty ready                                |
      {2: }                                                 |
                                                        |
      ^                                                  |
      :6put a                                           |
    ]])
  end)

  it('can be deleted', function()
    feed('<c-\\><c-n>:bd!<cr>')
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      :bd!                                              |
    ]])
    feed_command('bnext')
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      :bnext                                            |
    ]])
  end)

  it('handles loss of focus gracefully', function()
    -- Change the statusline to avoid printing the file name, which varies.
    nvim('set_option', 'statusline', '==========')
    feed_command('set laststatus=0')

    -- Save the buffer number of the terminal for later testing.
    local tbuf = eval('bufnr("%")')

    source([[
    function! SplitWindow(id, data, event)
      new
      call feedkeys("iabc\<Esc>")
    endfunction

    startinsert
    call jobstart(['sh', '-c', 'exit'], {'on_exit': function("SplitWindow")})
    call feedkeys("\<C-\>", 't')  " vim will expect <C-n>, but be exited out of
                                  " the terminal before it can be entered.
    ]])

    -- We should be in a new buffer now.
    screen:expect([[
      ab^c                                               |
      {4:~                                                 }|
      {5:==========                                        }|
      rows: 2, cols: 50                                 |
      {2: }                                                 |
      {1:==========                                        }|
                                                        |
    ]])

    neq(tbuf, eval('bufnr("%")'))
    feed_command('quit!')  -- Should exit the new window, not the terminal.
    eq(tbuf, eval('bufnr("%")'))

    feed_command('set laststatus=1')  -- Restore laststatus to the default.
  end)

  it('term_close() use-after-free #4393', function()
    feed_command('terminal yes')
    feed([[<C-\><C-n>]])
    feed_command('bdelete!')
  end)
end)

describe('No heap-buffer-overflow when using', function()

  local testfilename = 'Xtestfile-functional-terminal-buffers_spec'

  before_each(function()
    write_file(testfilename, "aaaaaaaaaaaaaaaaaaaaaaaaaaaa")
  end)

  after_each(function()
    os.remove(testfilename)
  end)

  it('termopen(echo) #3161', function()
    feed_command('edit ' .. testfilename)
    -- Move cursor away from the beginning of the line
    feed('$')
    -- Let termopen() modify the buffer
    feed_command('call termopen("echo")')
    wait()
    feed_command('bdelete!')
  end)
end)
