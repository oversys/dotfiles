-- General configuration
vim.cmd("filetype indent on")
vim.cmd("syntax on")
vim.wo.number = true
vim.wo.signcolumn = "no"
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.ttimeoutlen = 0
vim.opt.pumheight = 10
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.cursorline = true
vim.opt.scrolloff = 8

-- Remove terminal padding on entry
vim.api.nvim_create_autocmd("VimEnter", {
	pattern = '*',
	command = "silent !kitty @ set-spacing padding=0"
})

-- Restore terminal cursor and padding on exit
vim.api.nvim_create_autocmd("VimLeave", {
	pattern = '*',
	callback = function ()
		vim.cmd("set guicursor=a:ver25-blinkon1")
		vim.cmd("silent !kitty @ set-spacing padding=default")
	end
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

-- vim.g.mapleader = " "
-- vim.g.maplocalleader = " "

require("lazy").setup({
	-- File tabs
	{ "akinsho/bufferline.nvim", version = "*", dependencies = "nvim-tree/nvim-web-devicons",
		opts = {
			options = {
				separator_style = "slant",
				indicator = { style = "underline" },
				buffer_close_icon = '',
				offsets = {{
					filetype = "neo-tree",
					text = " Files",
					text_align = "center",
				}},
				diagnostics = "nvim_lsp",
				diagnostics_indicator = function(count, level)
					local icon = level:match("error") and "" or ""
					return icon .. " " .. count
				end
			}
		}
	},

	-- Status line
	{ "nvim-lualine/lualine.nvim", dependencies = "nvim-tree/nvim-web-devicons",
		opts = {
			options = {
				theme = "monokai-pro",
				section_separators = { left = '', right = '' },
				component_separators = { left = '', right = '' },
				disabled_filetypes = {
					winbar = { "gitcommit", "neo-tree", "toggleterm", "fugitive" },
				}
			}
		}
	},

	-- File explorer
	{ "nvim-neo-tree/neo-tree.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons", "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" },
		opts = {
			close_if_last_window = true,
			window = { width = 25 },
			filesystem = {
				filtered_items = {
					visible = true,
					hide_dotfiles = false,
					hide_gitignored = false,
				}
			}
		}
	},

	-- Visualize hex colors
	{ "lilydjwg/colorizer" },

	-- Colorscheme
	{ "loctvl842/monokai-pro.nvim",
		config = function ()
			require("monokai-pro").setup({
				devicons = true,
				transparent_background = true,
				filter = "spectrum",
				plugins = {
					bufferline = {
						underline_selected = true,
						underline_visible = false,
					}
				},
			})

			vim.cmd([[colorscheme monokai-pro]])
			vim.api.nvim_set_hl(0, "CursorLine", { bg = "#3a3a3a", blend = 10 })
		end
	},

	-- Syntax highlighting
	{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate",
		config = function ()
			require("nvim-treesitter.configs").setup({
				ensure_installed = { "c", "lua", "rust", "python" },
				sync_install = false,
				auto_install = true,
				highlight = { enable = true },
				indent = { enable = true },
			})
		end
	},

	-- Scroll animation
	{ "karb94/neoscroll.nvim" },

	-- Indent visualization
	{ "lukas-reineke/indent-blankline.nvim",
		config = function ()
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
		end
	},

	-- Autocomplete
	{ "hrsh7th/nvim-cmp",
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
					completion = { border = "rounded" },
					documentation = { border = "rounded" },
				},

				formatting = {
					format = lspkind.cmp_format({
						before = function (_, vim_item)
							-- Hide LSP `detail` content
							if (vim_item.menu ~= nil and string.len(vim_item.menu) > 0) then
								vim_item.menu = string.sub(vim_item.menu, 1, 0) .. ""
							end

							--[[ Truncate text longer than maxwidth
							local maxwidth = 40
							local ellipsis_char = "..."

							if (vim_item.menu ~= nil and string.len(vim_item.menu) > maxwidth) then
								vim_item.menu = string.sub(vim_item.menu, 1, maxwidth - 3) .. ellipsis_char
							end
							]]--

							return vim_item
						end
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
	{ "windwp/nvim-autopairs",
		config = function ()
			require("nvim-autopairs").setup({})
			local cmp_autopairs = require("nvim-autopairs.completion.cmp")
			require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
		end
	},

	-- Fuzzy finder
	{ "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = "nvim-lua/plenary.nvim" },

	-- Dashboard
	{ "goolord/alpha-nvim",
		dependencies = { "nvim-tree/nvim-web-devicons", "nvim-lua/plenary.nvim" },
		config = function ()
			local dashboard = require("alpha.themes.dashboard")

			package.path = package.path .. ';' .. vim.fn.stdpath('config') .. '/?.lua'
			local ascii_art = require("ascii_art")
			local keys = vim.tbl_keys(ascii_art)
			local random_key = keys[math.random(1, #keys)]
			dashboard.section.header.val = ascii_art[random_key]

			dashboard.section.buttons.val = {
				dashboard.button( "e", "󰝒    New file" , "<CMD>ene <BAR> startinsert<CR>"),
				dashboard.button( "f", "󰈞    Find file", "<CMD>Telescope find_files<CR>"),
				dashboard.button( "r", "󱋡    Recent"   , "<CMD>Telescope oldfiles<CR>"),
				dashboard.button( "q", "󰅚    Quit", "<CMD>qa<CR>"),
			}

			-- dashboard.section.footer.val = require("alpha.fortune")

			local plugins_count = #require("lazy").plugins()
			local datetime = os.date(" %m-%d-%Y    %H:%M:%S")
			local version = vim.version()
			local nvim_version_info = " v" .. version.major .. "." .. version.minor .. "." .. version.patch

			dashboard.section.footer.val = datetime .. "    " .. plugins_count .. " Plugins   " .. nvim_version_info

			vim.api.nvim_create_autocmd("User", {
				pattern = "AlphaReady",
				callback = function ()
					vim.opt.cmdheight = 0
					vim.opt.showtabline = 0
					vim.go.laststatus = 0
					vim.cmd("hi Cursor blend=100")
					vim.cmd("set guicursor+=a:Cursor/lCursor")
				end
			})

			vim.api.nvim_create_autocmd("BufUnload", {
				buffer = 0,
				callback = function ()
					vim.opt.cmdheight = 1
					vim.opt.showtabline = 2
					vim.go.laststatus = 3
					vim.cmd("set guicursor&")
				end
			})

			require("alpha").setup(dashboard.opts)
		end
	}
})

-- Key bindings
local function map_key(mode, keys, command)
	vim.keymap.set(mode, keys, command)
end

-- Toggle file explorer
map_key('n', "<C-t>", "<CMD>Neotree toggle<CR>")

-- Copy to system clipboard
map_key('n', "<leader>y", '"+yy')
map_key('v', "<leader>y", '"+y')

-- Press escape to clear search pattern highlighting
map_key('n', "<ESC>", "<CMD>nohlsearch<CR>")

-- Manage Tabs
map_key('n', "<C-Tab>", "<CMD>bnext<CR>")
map_key('n', "<C-S-Tab>", "<CMD>bprev<CR>")
map_key('n', "<C-w>", "<CMD>bdelete<CR>")

vim.api.nvim_del_keymap('n', "<C-W><C-D>")
vim.api.nvim_del_keymap('n', "<C-W>d")

for i = 1, 9 do
	map_key('n', "<C-" .. i .. ">", "<CMD>BufferLineGoToBuffer " .. i .. "<CR>")
end

-- Telescope
local builtin = require("telescope.builtin")
map_key('n', "<leader>tf", builtin.find_files)
map_key('n', "<leader>tr", builtin.oldfiles)
map_key('n', "<leader>th", builtin.help_tags)
map_key('n', "<leader>tb", builtin.buffers)
map_key('n', "<leader>tg", builtin.live_grep)
map_key('n', "<leader>td", builtin.diagnostics)
map_key('n', "<leader>tk", builtin.keymaps)

-- Go to definition/references
map_key('n', "gd", vim.lsp.buf.definition)
map_key('n', "gr", builtin.lsp_references)

-- Diagnostics
map_key('n', "<leader>dp", vim.diagnostic.goto_prev) -- Previous message
map_key('n', "<leader>dn", vim.diagnostic.goto_next) -- Next message
map_key('n', "<leader>dl", vim.diagnostic.open_float) -- Open diagnostic message(s) for current line
map_key('n', "<leader>do", vim.diagnostic.setloclist) -- Open buffer diagnostics

-- Toggle autopairs
map_key({ 'n', 'i' }, "<C-]>", function()
	local autopairs = require("nvim-autopairs")
	if autopairs.state.disabled then
		autopairs.enable()
		print("nvim-autopairs enabled")
	else
		autopairs.disable()
		print("nvim-autopairs disabled")
	end
end)

-- neoscroll
local neoscroll = require("neoscroll")

local function top_bot(keys)
	local win_height = vim.api.nvim_win_get_height(0)
	local buf_line_count = vim.api.nvim_buf_line_count(0)

	if buf_line_count < win_height then
		vim.cmd("normal! " .. keys)
	else
		local amount = (keys == 'G') and 1 or -1
		neoscroll.scroll(amount * buf_line_count, true, 1, 5)
	end
end

local modes = { 'n', 'v' }
map_key(modes, "<ScrollWheelUp>", function() neoscroll.scroll(-4, true, 50, "sine") end)
map_key(modes, "<ScrollWheelDown>", function() neoscroll.scroll(4, true, 50, "sine") end)
map_key(modes, "gg", function() top_bot("gg") end)
map_key(modes, 'G', function() top_bot('G') end)

