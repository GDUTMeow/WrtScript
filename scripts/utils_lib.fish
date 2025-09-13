function log_info
    printf "\033[36m%s %s\033[0m\n" "[INFO]" (string join " " $argv) >&2
end

function log_error
    printf "\033[31m%s %s\033[0m\n" "[ERROR]" (string join " " $argv) >&2
end

function log_success
    printf "\033[32m%s %s\033[0m\n" "[SUCCESS]" (string join " " $argv) >&2
end