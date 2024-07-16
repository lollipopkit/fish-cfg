## fish cfg

### Install

0. Clone to `~/.config/fish/`
  ```bash
  git clone git@github.com:lollipopkit/fish-cfg.git ~/.config/fish
  ```
1. Install fisher
  ```bash
  curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
  ```
2. Install plugins
  ```bash
  fisher install (cat ~/.config/fish/fish_plugins)
  ```