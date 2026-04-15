return {
  "neovim/nvim-lspconfig",
  config = function()
    vim.lsp.enable('lua_ls') -- This turns the server on
    
    vim.lsp.config('lua_ls', {
      settings = {
        Lua = {
          diagnostics = { globals = { 'vim' } }
        }
      }
    })
  end
}

