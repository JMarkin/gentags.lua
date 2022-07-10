# Auto generate tags


### Quck start

1. Install plugin
```lua
use({
    "JMarkin/gentags.lua",
    config = function()
        require("gentags").setup()
    end,
})
```
2. Generate and start auto generate on save `:GenTagsEnable
