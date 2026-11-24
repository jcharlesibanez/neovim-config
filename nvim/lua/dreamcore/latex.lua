-- Live LaTeX preview on top of vimtex: the PDF opens in Skim on the right side of the
-- screen and refreshes shortly after you stop typing.
local M = {}
local DEBOUNCE_MS = 700
local timers, pending, failing, placed = {}, {}, {}, {}

-- vimtex returns booleans from some functions and 0/1 from others.
local function vimtex_true(expr)
  local v = vim.fn.eval(expr)
  return v == true or v == 1
end

local function in_buf(buf, fn)
  if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_call(buf, fn) end
end

-- Start a single compile of the current buffer's document.
-- Never toggles: `:VimtexCompile` would *stop* a compile that's already running.
local function compile()
  local buf = vim.api.nvim_get_current_buf()
  if not vim.b.vimtex or not vimtex_true('b:vimtex.compiler.enabled') then return end
  -- A file that was empty when opened has no \documentclass, so vimtex couldn't work
  -- out the main file. Re-detect once there's content.
  if not vimtex_true('b:vimtex.is_compileable()') then
    vim.cmd('silent! VimtexReloadState')
    if not vim.b.vimtex or not vimtex_true('b:vimtex.is_compileable()') then return end
  end
  if vimtex_true('b:vimtex.compiler.is_running()') then
    pending[buf] = true -- run again as soon as this one finishes
    return
  end
  pending[buf] = nil
  vim.fn['vimtex#compiler#start']()
end
M.compile = compile

-- Put Skim on the right ~45% of the screen the first time a PDF is shown, then leave it
-- wherever you move it. JXA avoids hardcoding the screen size.
local function place_skim(pdf)
  if placed[pdf] or vim.g.vimtex_view_method ~= 'skim' then return end
  placed[pdf] = true
  local script = [[
    ObjC.import('AppKit');
    function run(argv) {
      const name = argv[0];
      const skim = Application('Skim');
      // Skim may still be opening the document: wait up to ~5 s for its window.
      for (let i = 0; i < 50; i++) {
        const wins = skim.windows().filter(w => { try { return w.document().name() === name; } catch (e) { return false; } });
        if (wins.length) {
          const screen = $.NSScreen.mainScreen;
          const full = screen.frame, vis = screen.visibleFrame;
          const top = full.size.height - (vis.origin.y + vis.size.height); // menu bar height
          const width = Math.round(vis.size.width * 0.45);
          wins[0].bounds = { x: vis.origin.x + vis.size.width - width, y: top, width: width, height: vis.size.height };
          return 'placed';
        }
        delay(0.1);
      }
      return 'no window';
    }
  ]]
  vim.system({ 'osascript', '-l', 'JavaScript', '-e', script, vim.fs.basename(pdf) }, { text = true })
end

function M.setup()
  local group = vim.api.nvim_create_augroup('dreamcore_latex', { clear = true })

  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'tex',
    callback = function(args)
      local buf = args.buf
      -- Compilers read the file on disk, so <space>ll saves first.
      vim.keymap.set('n', '<localleader>ll', function()
        vim.cmd('silent! update')
        compile()
      end, { buffer = buf, desc = 'Save and compile LaTeX' })

      -- Live preview: save shortly after you stop typing (insert or normal mode);
      -- the save triggers a compile, and Skim reloads the PDF.
      vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
        group = group,
        buffer = buf,
        callback = function()
          timers[buf] = timers[buf] or vim.uv.new_timer()
          timers[buf]:stop()
          timers[buf]:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
            in_buf(buf, function()
              if vim.bo.modified and vim.api.nvim_buf_get_name(0) ~= '' then vim.cmd('silent! update') end
            end)
          end))
        end,
      })
      vim.api.nvim_create_autocmd('BufWipeout', {
        group = group,
        buffer = buf,
        callback = function()
          if timers[buf] then timers[buf]:stop(); timers[buf]:close(); timers[buf] = nil end
          pending[buf], failing[buf] = nil, nil
        end,
      })
    end,
  })

  -- latexmk watches the file itself; Tectonic compiles once per request, so compile on save.
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = '*.tex',
    callback = function(args)
      if vim.g.vimtex_compiler_method == 'tectonic' then in_buf(args.buf, compile) end
    end,
  })

  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = { 'VimtexEventCompileSuccess', 'VimtexEventCompileFailed' },
    callback = function(ev)
      local buf = vim.api.nvim_get_current_buf()
      if ev.match == 'VimtexEventCompileSuccess' then
        failing[buf] = nil
        if vim.b.vimtex then place_skim(vim.fn.eval('b:vimtex.compiler.get_file("pdf")')) end
      elseif not failing[buf] then
        -- Half-typed LaTeX fails a lot while you write; say so once, not on every keystroke.
        failing[buf] = true
        vim.notify('LaTeX has an error, so the PDF is paused. <space>le shows it.', vim.log.levels.WARN)
      end
      if pending[buf] then vim.schedule(function() in_buf(buf, compile) end) end
    end,
  })
end

return M
