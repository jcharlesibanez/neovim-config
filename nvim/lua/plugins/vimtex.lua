return {
  {
    "lervag/vimtex",
    -- Newer vimtex requires Neovim 0.12.4+; v2.18 is the last release supporting 0.11.
    -- Remove this pin after upgrading Neovim.
    tag = "v2.18",
    lazy = false, -- vimtex sets itself up on filetype detection; lazy-loading breaks it
    init = function()
      -- Compiler: latexmk (MacTeX/BasicTeX) if present, otherwise Tectonic.
      if vim.fn.executable("latexmk") == 0 and vim.fn.executable("tectonic") == 1 then
        vim.g.vimtex_compiler_method = "tectonic"
      end

      -- Viewer: Skim supports jumping between source and PDF; otherwise macOS `open` (Preview).
      if vim.fn.isdirectory("/Applications/Skim.app") == 1 then
        vim.g.vimtex_view_method = "skim"
        vim.g.vimtex_view_skim_sync = 1      -- jump the PDF to the cursor after each compile
        vim.g.vimtex_view_skim_activate = 0  -- keep focus in the terminal
      else
        vim.g.vimtex_view_method = "general"
        vim.g.vimtex_view_general_viewer = "open"
      end

      -- Live preview compiles constantly and half-typed LaTeX fails often: don't pop the
      -- error list open or print a message on every compile. <space>le shows errors.
      vim.g.vimtex_quickfix_mode = 0
      vim.g.vimtex_compiler_silent = 1
    end,
    config = function()
      require("dreamcore.latex").setup() -- live preview: Skim on the right, refresh as you type
    end,
  },
}
