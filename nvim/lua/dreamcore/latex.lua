-- Live LaTeX preview on top of vimtex: the PDF refreshes shortly after you stop typing.
-- In Ghostty/kitty it's drawn in a split on the right inside Neovim; elsewhere (iTerm2)
-- it opens in Skim on the right side of the screen.
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

-- ── In-Neovim preview (Ghostty / kitty) ────────────────────────────────────
-- Terminals with the kitty graphics protocol can draw images, so the PDF page is shown
-- in a split on the right instead of in Skim. iTerm2 can't, so it keeps using Skim.

function M.inline_supported()
  return vim.env.TERM_PROGRAM == 'ghostty' or vim.env.KITTY_WINDOW_ID ~= nil or vim.env.SNACKS_GHOSTTY == 'true'
end

local preview = { buf = nil, win = nil, pdf = nil, page = 1, pages = 1, copy = nil, n = 0 }
local copies_dir = vim.fn.stdpath('cache') .. '/latex-preview'

local function preview_open()
  return preview.win and vim.api.nvim_win_is_valid(preview.win)
end

local function set_winbar()
  if not preview_open() then return end
  vim.wo[preview.win].winbar = ('%%#BadgeDim# page %d/%d   Ctrl-j / Ctrl-k to flip%%*'):format(preview.page, preview.pages)
end

-- Open the split on the right without moving the cursor out of the .tex file.
local function open_window()
  if preview_open() then return end
  if not (preview.buf and vim.api.nvim_buf_is_valid(preview.buf)) then
    preview.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[preview.buf].bufhidden = 'hide'
    vim.api.nvim_buf_set_name(preview.buf, 'PDF preview')
  end
  local from = vim.api.nvim_get_current_win()
  preview.win = vim.api.nvim_open_win(preview.buf, false, {
    split = 'right', win = -1, width = math.floor(vim.o.columns * 0.45),
  })
  for opt, val in pairs({
    number = false, relativenumber = false, signcolumn = 'no', cursorline = false,
    foldcolumn = '0', list = false, winfixwidth = true, statuscolumn = '',
  }) do vim.wo[preview.win][opt] = val end
  if vim.api.nvim_win_is_valid(from) then vim.api.nvim_set_current_win(from) end
end

-- Draw the current page. snacks caches rendered pages by file path + page, so each
-- compile gets a fresh copy of the PDF; otherwise the old page would keep showing.
local function render()
  if not (preview_open() and preview.pdf and vim.fn.filereadable(preview.pdf) == 1) then return end
  vim.fn.mkdir(copies_dir, 'p')
  local old = preview.copy
  preview.n = preview.n + 1
  preview.copy = ('%s/%s-%d.pdf'):format(copies_dir, vim.fn.sha256(preview.pdf):sub(1, 8), preview.n)
  vim.uv.fs_copyfile(preview.pdf, preview.copy)
  local src = preview.copy .. '#page=' .. preview.page
  -- Wait for snacks to finish detecting the terminal's graphics support before drawing.
  require('snacks.image.terminal').detect(function()
    if not preview_open() then return end
    Snacks.image.placement.clean(preview.buf)
    Snacks.image.placement.new(preview.buf, src, { conceal = true, auto_resize = true })
  end)
  set_winbar()
  if old then vim.defer_fn(function() vim.uv.fs_unlink(old) end, 5000) end
end

-- Ask Ghostscript for the page count (fast: doesn't render anything), then draw.
local function refresh(pdf)
  preview.pdf = pdf
  open_window()
  local ps_path = pdf:gsub('[()\\]', '\\%0') -- escape for a PostScript string
  vim.system({ 'gs', '-q', '-dNODISPLAY', '-dNOSAFER', '-c', ('(%s) (r) file runpdfbegin pdfpagecount = quit'):format(ps_path) },
    { text = true }, function(res)
      vim.schedule(function()
        preview.pages = tonumber(vim.trim(res.stdout or '')) or preview.pages
        preview.page = math.max(1, math.min(preview.page, preview.pages))
        render()
      end)
    end)
end

local function flip(delta)
  if not preview_open() then return end
  local page = math.max(1, math.min(preview.page + delta, preview.pages))
  if page ~= preview.page then preview.page = page; render() end
end

local function toggle_preview()
  if preview_open() then
    vim.api.nvim_win_close(preview.win, true)
    preview.win = nil
  elseif vim.b.vimtex then
    local pdf = vim.fn.eval('b:vimtex.compiler.get_file("pdf")')
    if pdf ~= '' and vim.fn.filereadable(pdf) == 1 then refresh(pdf) else vim.notify('No PDF yet: start typing or press <space>ll.') end
  end
end

local function show_pdf(pdf)
  if M.inline_supported() then refresh(pdf) else place_skim(pdf) end
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

      if M.inline_supported() then
        vim.keymap.set('n', '<C-j>', function() flip(1) end, { buffer = buf, desc = 'PDF preview: next page' })
        vim.keymap.set('n', '<C-k>', function() flip(-1) end, { buffer = buf, desc = 'PDF preview: previous page' })
        vim.keymap.set('n', '<localleader>lp', toggle_preview, { buffer = buf, desc = 'Toggle PDF preview split' })
        -- Already compiled before? Show it straight away.
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(buf) then return end
          in_buf(buf, function()
            if not vim.b.vimtex then return end
            local pdf = vim.fn.eval('b:vimtex.compiler.get_file("pdf")')
            if pdf ~= '' and vim.fn.filereadable(pdf) == 1 and not preview_open() then refresh(pdf) end
          end)
        end)
      end

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

  -- Drop the per-compile PDF copies made for the preview.
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function() vim.fn.delete(copies_dir, 'rf') end,
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
        if vim.b.vimtex then show_pdf(vim.fn.eval('b:vimtex.compiler.get_file("pdf")')) end
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
