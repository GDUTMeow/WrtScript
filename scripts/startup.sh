# 创建会话
tmux new-session -d -s "kc"

# 获取 tmux 默认使用的 shell
TMUX_SHELL=$(tmux show-options -gv default-shell 2>/dev/null)
if [ -z "$TMUX_SHELL" ]; then
    TMUX_SHELL="$SHELL"
fi

# 根据 shell 类型决定 source 命令
case "$TMUX_SHELL" in
    *fish)
        SOURCE_CMD="source .envrc"
        ;;
    *)
        # ash/bash/sh 环境下使用 . 且必须带路径以兼容所有环境
        SOURCE_CMD=". ./.envrc"
        ;;
esac

# 发送指令
tmux send-keys -t "kc" "$SOURCE_CMD" Enter "./kc.fish" Enter

exit 0
