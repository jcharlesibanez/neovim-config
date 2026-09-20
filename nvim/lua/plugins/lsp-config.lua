return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      { "williamboman/mason.nvim", opts = {} },
      {
        "williamboman/mason-lspconfig.nvim",
        opts = {
          ensure_installed = { "lua_ls", "ts_ls", "html", "pyright", "clangd" },
          automatic_enable = true,
        },
      },
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      vim.lsp.config("*", { capabilities = capabilities })

      -- vscode-langservers-extracted ships all four binaries together. Point
      -- the related servers at the copy Mason already installed for HTML so
      -- setup stays fast and does not download the same 90 MB package 4 times.
      local vscode_bin = vim.fn.stdpath("data")
        .. "/mason/packages/html-lsp/node_modules/.bin/"
      vim.lsp.config("lua_ls", {
        settings = { Lua = { diagnostics = { globals = { "vim" } } } },
      })
      vim.lsp.config("ts_ls", {
        settings = {
          completions = { completeFunctionCalls = true },
          javascript = { inlayHints = { includeInlayParameterNameHints = "literals" } },
          typescript = { inlayHints = { includeInlayParameterNameHints = "literals" } },
        },
      })
      vim.lsp.config("cssls", { cmd = { vscode_bin .. "vscode-css-language-server", "--stdio" } })
      vim.lsp.config("jsonls", { cmd = { vscode_bin .. "vscode-json-language-server", "--stdio" } })
      vim.lsp.config("eslint", { cmd = { vscode_bin .. "vscode-eslint-language-server", "--stdio" } })
      vim.lsp.config("pyright", {
        before_init = function(_, config)
          config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
            python = { pythonPath = require("dreamcore.workbench").python(config.root_dir or vim.fn.getcwd()) },
          })
        end,
      })
      vim.lsp.config("clangd", { cmd = { "clangd", "--background-index", "--clang-tidy" } })
      vim.lsp.enable({ "lua_ls", "ts_ls", "html", "cssls", "jsonls", "eslint", "pyright", "clangd" })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(event)
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = event.buf, desc = desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to Definition")
          map("gr", vim.lsp.buf.references, "Find References")
          map("K", vim.lsp.buf.hover, "Code Documentation")
          map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
          map("<leader>rn", vim.lsp.buf.rename, "Rename Symbol")
        end,
      })
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" }, { name = "luasnip" }, { name = "path" },
        }, { { name = "buffer", keyword_length = 3 } }),
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })
    end,
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = { check_ts = true },
    config = function(_, opts)
      require("nvim-autopairs").setup(opts)
      local cmp = require("cmp")
      cmp.event:on("confirm_done", require("nvim-autopairs.completion.cmp").on_confirm_done())
    end,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    opts = {
      formatters_by_ft = {
        javascript = { "prettier", stop_after_first = true },
        javascriptreact = { "prettier", stop_after_first = true },
        typescript = { "prettier", stop_after_first = true },
        typescriptreact = { "prettier", stop_after_first = true },
        html = { "prettier", stop_after_first = true },
        css = { "prettier", stop_after_first = true },
        scss = { "prettier", stop_after_first = true },
        json = { "prettier", stop_after_first = true },
        jsonc = { "prettier", stop_after_first = true },
      },
      format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
        return { timeout_ms = 1500, lsp_format = "fallback" }
      end,
      formatters = {
        prettier = { require_cwd = true },
      },
    },
  },
}
