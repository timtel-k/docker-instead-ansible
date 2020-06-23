source /etc/bash_completion

source ~/.bash_aliases

source <(kubectl completion bash)
complete -F __start_kubectl k