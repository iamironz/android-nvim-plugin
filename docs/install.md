# Install

## Purpose

Provide installation snippets for common plugin managers.

## Required Setup After Install

Call setup once in your Neovim config:

```lua
require("android").setup()
```

## lazy.nvim

```lua
{
  "iamironz/android-nvim-plugin",
  lazy = false,
  config = function()
    require("android").setup()
  end,
}
```

## packer.nvim

```lua
require("packer").startup(function(use)
  use({
    "iamironz/android-nvim-plugin",
    config = function()
      require("android").setup()
    end,
  })
end)
```

## pckr.nvim

```lua
require("pckr").add({
  {
    "iamironz/android-nvim-plugin",
    config = function()
      require("android").setup()
    end,
  },
})
```

## mini.deps

```lua
local add = MiniDeps.add

add({ source = "iamironz/android-nvim-plugin" })
require("android").setup()
```

## rocks.nvim

Use rocks.nvim with rocks-git.nvim for Git repositories. Add the repo to
`rocks.toml`, then load the plugin and call setup.

## vim-plug

```vim
call plug#begin(stdpath('data') . '/plugged')
Plug 'iamironz/android-nvim-plugin'
call plug#end()
lua require("android").setup()
```

## dein.vim

```vim
call dein#begin(stdpath('data') . '/dein')
call dein#add('iamironz/android-nvim-plugin')
call dein#end()
lua require("android").setup()
```

## paq-nvim

```lua
require("paq")({
  { "iamironz/android-nvim-plugin" },
})
require("android").setup()
```

## vim.pack

```bash
git clone https://github.com/iamironz/android-nvim-plugin \
  ~/.local/share/nvim/site/pack/android/start/android-nvim-plugin
```

```lua
require("android").setup()
```

## Next Step

Continue with [getting-started.md](getting-started.md).
