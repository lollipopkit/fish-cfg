set -x PATH $PATH ~/.cargo/bin
set -x PATH $PATH ~/.local/bin
set -x PATH $PATH ~/env/flutter/bin
set -x PATH $PATH ~/go/bin
set -x PATH $PATH ~/env/android/cmdline-tools/latest/bin
set -x PATH $PATH ~/env/android/platform-tools
set -x PATH $PATH ~/proj/fvck_adb_mDNS
set -x PATH $PATH /usr/local/go/bin

set -x SHELL /usr/bin/fish
set -x TZ Asia/Shanghai
set -x LC_ALL en_US.UTF-8
set -x EDITOR vim
set -x ANDROID_HOME ~/env/android
set -x DOCKER_HOST unix:///run/user/1000/docker.sock
set -x FIC $HOME/.config/fish/config.fish
set -x FIH $HOME/.local/share/fish/fish_history

status is-interactive || exit

set -g fish_greeting
set -g sudope_sequence \cs
set -g sponge_successful_exit_codes 0 130
set -g sponge_delay 5
set -g hydro_symbol_prompt '>'
set -g hydro_symbol_git_dirty '!'
set -g hydro_color_pwd BB2D6F
set -g hydro_color_prompt BB2D6F

alias dps 'docker ps -a --format "table {{printf \"%-15.15s %-15.15s %-30.30s %-15.15s\" .ID .Names .Image .Status}}"'
alias dcp 'docker compose'
alias ulog 'journalctl --user -u'
alias slog 'journalctl -u'
alias uctl 'systemctl --user'
alias sctl 'systemctl'
alias fgl 'flutter gen-l10n'
alias fpg 'flutter pub get'
alias dfmt 'dart format .'
alias gtp 'git_tag_push'
alias ka 'kill_all'
alias gr 'go run'
alias gmt 'go mod tidy'

set SSH_ENV "$HOME/.ssh/agent-environment"

function start_ssh_agent -d "Start a new SSH agent"
    echo "Initialising new SSH agent..."

    /usr/bin/ssh-agent | sed 's/^echo/#echo/' | sed 's/;.*$//' | sed -E 's/([A-Z_][A-Z0-9_]+)=(.*)/set -x \1 \2/g' > "$SSH_ENV"

    chmod 600 "$SSH_ENV"
    source "$SSH_ENV" > /dev/null
    /usr/bin/ssh-add
end

if test -f "$SSH_ENV"
    . "$SSH_ENV" > /dev/null
    or start_ssh_agent
else
    start_ssh_agent
end

function compress -d "Compress dir to tar.gz"
    if test (count $argv) -eq 0
        echo "Usage: compress <dir>"
        return 1
    end
    tar -czvf $argv[1].tar.gz $argv[1]
end

function kill_all -d "Kill all processes with a keyword"
    if test (count $argv) -eq 0
        echo "Usage: kill_all <keyword>"
        return 1
    end

    set keyword $argv[1]
    ps aux | grep "$keyword" | grep -v grep | awk '{print $2}' | xargs -r kill -9
end

function git_tag_push -d "Create a tag and push it to the remote"
    set tag ""
    if test (count $argv) -ge 1
        set tag $argv[1]
    else
        set count (git rev-list --count HEAD)
        set tag "v1.0.$count"
    end

    set msg $tag
    if test (count $argv) -ge 2
        set msg $argv[2]
    end

    git tag -a "$tag" -m "$msg"
    or return 1

    git push origin "$tag"
    or return 1

    echo "Tag $tag pushed successfully"
end

function mdc -d "Make directory and cd into it"
    mkdir -p $argv[1]
    cd $argv[1]
end

# Usage:
#   git_merge <user>[/<repo>] -b [<branch>] -d [<domain>]
# args:
#   user: can't be empty
#   repo: can be empty, if empty, use current repo name
#   branch: default main
#   domain: default github.com
# eg:
#   git_merge user
#   git_merge user/new_repo -b main
#   git_merge user/repo -d gitlab.com
function git_merge -d "Merge a remote repository"
    set user $argv[1]
    set repo ""
    set branch "main"
    set domain "github.com"

    # Remove first arg in argv list
    set argv (echo $argv[2..-1])
    
    for i in (seq 2 2 (count $argv))
        switch $argv[$i]
            case "-b"
                set -l branch_ $argv[(math $i + 1)]
                if test -n "$branch_"
                    set branch $branch_
                end
            case "-d"
                set -l domain_ $argv[(math $i + 1)]
                if test -n "$domain_"
                    set domain $domain_
                end
        end
    end

    if test (count $argv) -ge 3
        set repo $argv[2]
    else
        set repo (basename (git remote get-url origin) .git)
    end

    set url "git@$domain:$user/$repo.git"

    # Ask confirmation
    echo $url
    echo $branch
    echo "continue? [y/n]"
    read -l confirm
    if test "$confirm" != "y"
        return 0
    end

    # If remote not exists
    if not git remote | grep -q $user
        git remote add $user $url
    end
    
    echo "Fetching..."
    git fetch $user
    echo "Merging..."
    git merge --squash $user/$branch
end

function git_first -d "Get the first commit of a git repository"
    echo "Git First"
    set first_commit (git rev-list --max-parents=0 HEAD)
    echo "Hash: [\033[33m$first_commit\033[0m]"
    echo "Date: [\033[32m(git show -s --format=%ci $first_commit)\033[0m]"
    set files_changed (git show --pretty="" --name-only $first_commit)
    set first_file (echo "$files_changed" | sed -n 1p)
    echo "File: [\033[34m$first_file\033[0m]"
    set first_line (git show $first_commit:$first_file | head -1)
    echo "Line: [\033[35m$first_line\033[0m]"
end

function git_lines -d "Get the lines of code of a git repository"
    set name (git config user.name)

    set_color yellow
    echo -n "["
    echo -n (set_color yellow) $name (set_color normal)
    echo -n "] at ["
    echo -n (set_color green) (date) (set_color normal)
    echo "]"
    git log --author="$name" --pretty=tformat: --numstat -- $dir | awk '{ add += $1 ; subs += $2 ; loc += $1 + $2 } END { printf "added lines: \033[34m%d\033[0m, removed lines: \033[31m%d\033[0m, total lines: \033[32m%d\033[0m\n", add, subs, loc }'
end
