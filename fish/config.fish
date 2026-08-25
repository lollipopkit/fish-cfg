# Homebrew 未把自己写进 PATH 时(新机器首次装完),按已知安装位置探测并加载
if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
else if test -x /usr/local/bin/brew
    eval (/usr/local/bin/brew shellenv)
else if test -x /home/linuxbrew/.linuxbrew/bin/brew
    eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
end

if test (uname) = Darwin
    fish_add_path /Applications/Xcode.app/Contents/Developer/usr/bin
end
fish_add_path ~/.local/bin
fish_add_path ~/go/bin
fish_add_path /usr/local/go/bin
fish_add_path ~/env/flutter/bin
fish_add_path ~/.bun/bin
fish_add_path ~/.cargo/bin
fish_add_path ~/.pub-cache/bin

set -x SHELL (status fish-path)
set -x TZ Asia/Singapore
set -x LC_ALL en_US.UTF-8
set -x EDITOR vim
#set -x DOCKER_HOST unix:///run/user/1000/docker.sock
set -x PIMM_API_KEY (cat ~/.config/llm_keys/pimm)
set -x PIMM_BASE_URL "https://cpa.lolli.tech/v1"

# 无显示器 / 无头环境下,让需要打开浏览器的工具改为直接打印链接
set -l headless 0
if test (uname) = Linux
    if not set -q DISPLAY; and not set -q WAYLAND_DISPLAY
        set headless 1
    end
else if set -q SSH_CONNECTION
    set headless 1
end
if test $headless = 1
    set -x BROWSER echo
end
set -x FIC $HOME/.config/fish/config.fish
set -x FIH $HOME/.local/share/fish/fish_history
set -gx NVM_DIR $HOME/.nvm
set -gx BUN_INSTALL "$HOME/.bun"

set -g fish_greeting
set -g sponge_successful_exit_codes 0 130 255
set -g sponge_purge_only_on_exit true
set -g hydro_symbol_prompt '>'
set -g hydro_symbol_git_dirty '!'

alias dps 'docker ps -a --format "table {{printf \"%-15.15s %-15.15s %-30.30s %-15.15s\" .ID .Names .Image .Status}}"'
alias dcp 'docker compose'
alias ulog 'journalctl --user -u'
alias uctl 'systemctl --user'
alias dp 'dart pub'
alias drbb 'dart run build_runner build --delete-conflicting-outputs'
alias scpr 'rsync -P --rsh=ssh'
alias fl_build 'dart run fl_build'

if not command -q npm
    nvm use lts >/dev/null
end

function ccpxy -d "Claude Code with Profile-based models"
    # By default, pass all args through to claude
    set -l claude_args $argv

    # If the first arg is not an option, treat it as the profile
    if test (count $argv) -ge 1
        if not string match -qr '^-{1,2}' -- $argv[1]
            set profile $argv[1]
            set claude_args $argv[2..-1]
        end
    end

    # Anthropic SDK 会自行追加 /v1/messages,base URL 不能带 /v1
    set -x ANTHROPIC_BASE_URL (string replace -r '/v1/?$' '' -- $PIMM_BASE_URL)
    set -x ANTHROPIC_AUTH_TOKEN $PIMM_API_KEY

    # Set profile-specific models
    switch "$profile"
        case "muse"
            set -x ANTHROPIC_DEFAULT_FABLE_MODEL 'muse-spark-1.2-contributor'
            set -x ANTHROPIC_DEFAULT_OPUS_MODEL 'muse-spark-1.2-contributor'
            set -x ANTHROPIC_DEFAULT_SONNET_MODEL 'muse-spark-1.2-contributor'
            set -x ANTHROPIC_DEFAULT_HAIKU_MODEL 'muse-spark-1.2-contributor'
        case "ds4f"
            set -x ANTHROPIC_DEFAULT_FABLE_MODEL 'deepseek-v4-flash'
            set -x ANTHROPIC_DEFAULT_OPUS_MODEL 'deepseek-v4-flash'
            set -x ANTHROPIC_DEFAULT_SONNET_MODEL 'deepseek-v4-flash'
            set -x ANTHROPIC_DEFAULT_HAIKU_MODEL 'deepseek-v4-flash'
        case "sol"
            set -x ANTHROPIC_DEFAULT_FABLE_MODEL 'gpt-5.6-sol'
            set -x ANTHROPIC_DEFAULT_OPUS_MODEL 'gpt-5.6-sol'
            set -x ANTHROPIC_DEFAULT_SONNET_MODEL 'gpt-5.6-sol'
            set -x ANTHROPIC_DEFAULT_HAIKU_MODEL 'gpt-5.6-sol'
        case "luna"
            set -x ANTHROPIC_DEFAULT_FABLE_MODEL 'gpt-5.6-luna'
            set -x ANTHROPIC_DEFAULT_OPUS_MODEL 'gpt-5.6-luna'
            set -x ANTHROPIC_DEFAULT_SONNET_MODEL 'gpt-5.6-luna'
            set -x ANTHROPIC_DEFAULT_HAIKU_MODEL 'gpt-5.6-luna'
        case "c"
            # pass
        case "*"
            echo "Unknown profile: $profile"
            echo "Available profiles: $profiles"
            return 0
    end

    claude $claude_args
end