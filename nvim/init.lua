-- General configuration
vim.cmd("filetype indent on")
vim.cmd("syntax on")
vim.wo.number = true
vim.wo.signcolumn = "no"
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.ttimeoutlen = 0
vim.opt.pumheight = 10
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Key bindings
local function map(mode, keys, command, noremap)
	vim.api.nvim_set_keymap(mode, keys, command, { noremap = noremap, silent = true })
end

map('n', "<C-t>", ":Neotree toggle<CR>", true) -- Toggle file explorer
map('n', "<C-A-c>", '"+y$', false) -- Copy to system clipboard

-- Manage Tabs
map('n', "<A-.>", ":bnext<CR>", false)
map('n', "<A-,>", ":bprev<CR>", false)
map('n', "<A-c>", ":bdelete<CR>", false)

-- Restore terminal cursor on exit
vim.api.nvim_create_autocmd("VimLeave", {
    pattern = '*',
    command = "set guicursor=a:ver25-blinkon1"
})

-- Lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

--vim.g.mapleader = " "
--vim.g.maplocalleader = " "

require("lazy").setup({
	-- File tabs
	{ "akinsho/bufferline.nvim", version = "*", dependencies = "nvim-tree/nvim-web-devicons", config = function ()
		require("bufferline").setup({ options = {
			separator_style = "slant",
			indicator = { style = "none" },
			buffer_close_icon = '',
			close_icon = '',
			modified_icon = '●',
			left_trunc_marker = '',
			right_trunc_marker = '',
			diagnostics = "nvim_lsp",
			show_buffer_icons = true,
			show_buffer_close_icons = true,
			show_close_icon = true,
			persist_buffer_sort = true,
			enforce_regular_tabs = true,
			diagnostics_indicator = function(count, level)
				local icon = level:match("error") and "" or ""
				return icon .. " " .. count
			end
		}})
	end },

	-- Status line
	{ "nvim-lualine/lualine.nvim", dependencies = "nvim-tree/nvim-web-devicons", config = function ()
		require("lualine").setup({
			options = {
				theme = "monokai-pro",
				section_separators = { left = '', right = '' },
				disabled_filetypes = { -- Recommended filetypes to disable winbar
					winbar = { "gitcommit", "neo-tree", "toggleterm", "fugitive" },
				}
			}
		})
	end },

	-- File explorer
	{ "nvim-neo-tree/neo-tree.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons", "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" },
		config = function ()
			require("neo-tree").setup({
				close_if_last_window = true,
				window = { width = 25 },
				filesystem = {
					filtered_items = {
					visible = true,
					hide_dotfiles = false,
					hide_gitignored = false,
					}
				}
			})
		end
	},

	-- Visualize hex colors
	{ "lilydjwg/colorizer" },

	-- Colorscheme
	{ "loctvl842/monokai-pro.nvim", config = function ()
		require("monokai-pro").setup({ filter = "spectrum" })
		vim.cmd([[colorscheme monokai-pro]])
	end },

	-- Syntax highlighting
	{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate", config = function ()
		require("nvim-treesitter.configs").setup {
			ensure_installed = { "c", "lua", "rust", "python" },
			sync_install = false,
			auto_install = true,
			ignore_install = {},

			highlight = {
				enable = true,
				disable = {},
				additional_vim_regex_highlighting = false
			}
		}
	end },

	-- Scroll animation
	{ "karb94/neoscroll.nvim", config = function ()
		require("neoscroll").setup({ easing_function = "quadratic" })

		local t = {}
		t["<ScrollWheelUp>"] = {"scroll", {"-vim.wo.scroll", "true", "200"}}
		t["<ScrollWheelDown>"] = {"scroll", { "vim.wo.scroll", "true", "200"}}
		t["gg"] = {"scroll", {"-vim.api.nvim_buf_line_count(0)", "true", "500"}}
		t["G"] = {"scroll", {"vim.api.nvim_buf_line_count(0)", "true", "500"}}

		require("neoscroll.config").set_mappings(t)
	end },

	-- Indent visualization
	{ "lukas-reineke/indent-blankline.nvim", config = function ()
		local highlight = { "Red", "Yellow", "Green", "Blue", "Magenta" }

		local hooks = require("ibl.hooks")
		hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
			vim.api.nvim_set_hl(0, "Red", { fg = "#ff618d" })
			vim.api.nvim_set_hl(0, "Yellow", { fg = "#fce566" })
			vim.api.nvim_set_hl(0, "Green", { fg = "#7bd88f" })
			vim.api.nvim_set_hl(0, "Blue", { fg = "#5ad4e6" })
			vim.api.nvim_set_hl(0, "Magenta", { fg = "#948ae3" })
		end)

		require("ibl").setup({
			indent = {
				char = "▏",
				tab_char = "▏",
				highlight = highlight,
			}
		})
	end },

	-- Autocomplete
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"neovim/nvim-lspconfig",
			"onsails/lspkind.nvim",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-nvim-lsp-signature-help",
			"hrsh7th/cmp-nvim-lua",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			"hrsh7th/cmp-vsnip",
			"hrsh7th/vim-vsnip"
		},
		config = function ()
			vim.opt.completeopt = { "menu", "menuone", "noselect" }

			local lspkind = require("lspkind")
			local cmp = require("cmp")
			cmp.setup({
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},

				formatting = {
					format = lspkind.cmp_format({
						mode = "symbol_text",
						maxwidth = 50,
						ellipsis_char = "...",
					})
				},

				snippet = {
					expand = function(args)
						vim.fn["vsnip#anonymous"](args.body)
					end
				},

				mapping = cmp.mapping.preset.insert({
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					["<Tab>"] = cmp.mapping.confirm({ select = true })
				}),

				sources = cmp.config.sources({
						{ name = "nvim_lsp" },
						{ name = "vsnip" },
						{ name = "nvim_lsp_signature_help" }
					}, {
						{ name = "buffer" }
				})
			})

			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			local servers = { "pyright", "tsserver", "rust_analyzer", "clangd", "html", "cssls" }

			for _, lsp in ipairs(servers) do
				require("lspconfig")[lsp].setup {
					capabilities = capabilities,
				}
			end

			require("lspconfig")["lua_ls"].setup {
				capabilities = capabilities,
				settings = { Lua = { diagnostics = { globals = { "vim" } } } }
			}
		end
	},

	-- Auto close
	{ "alvan/vim-closetag" },
	{ "windwp/nvim-autopairs", config = function ()
		require("nvim-autopairs").setup({})
		local cmp_autopairs = require("nvim-autopairs.completion.cmp")
		require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
	end }
})

