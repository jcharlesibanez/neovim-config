return {
  -- Your code crumbles and falls like sand (:rain) or plays the Game of Life (:life).
  -- Any key stops it; the file isn't changed.
  {
    "Eandrju/cellular-automaton.nvim",
    cmd = "CellularAutomaton",
    keys = { { "<leader>fml", "<cmd>CellularAutomaton make_it_rain<CR>", desc = "Make it rain" } },
    init = function()
      vim.api.nvim_create_user_command("Rain", "CellularAutomaton make_it_rain", { desc = "Code falls like sand" })
      vim.api.nvim_create_user_command("Life", "CellularAutomaton game_of_life", { desc = "Code plays the Game of Life" })
      vim.cmd([[cnoreabbrev <expr> rain getcmdtype() == ':' && getcmdline() ==# 'rain' ? 'Rain' : 'rain']])
      vim.cmd([[cnoreabbrev <expr> life getcmdtype() == ':' && getcmdline() ==# 'life' ? 'Life' : 'life']])
    end,
  },
}
