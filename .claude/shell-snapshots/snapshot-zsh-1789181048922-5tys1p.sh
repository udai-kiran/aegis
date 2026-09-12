# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
__arguments () {
	# undefined
	builtin autoload -XUz
}
__conda_activate () {
	if [ -n "${CONDA_PS1_BACKUP:+x}" ]
	then
		PS1="$CONDA_PS1_BACKUP" 
		\unset CONDA_PS1_BACKUP
	fi
	\local ask_conda
	ask_conda="$(PS1="${PS1:-}" __conda_exe shell.posix "$@")"  || \return
	\eval "$ask_conda"
	__conda_hashr
}
__conda_exe () {
	(
		if [ -n "${_CE_M:+x}" ] && [ -n "${_CE_CONDA:+x}" ]
		then
			"$CONDA_EXE" $_CE_M $_CE_CONDA "$@"
		else
			"$CONDA_EXE" "$@"
		fi
	)
}
__conda_hashr () {
	if [ -n "${ZSH_VERSION:+x}" ]
	then
		\rehash
	elif [ -n "${POSH_VERSION:+x}" ]
	then
		:
	else
		\hash -r
	fi
}
__conda_reactivate () {
	echo "'__conda_reactivate' is deprecated and will be removed in 25.9. Use '__conda_activate reactivate' instead." >&2
	__conda_activate reactivate
}
__nvm () {
	declare previous_word
	previous_word="${COMP_WORDS[COMP_CWORD - 1]}" 
	case "${previous_word}" in
		(use | run | exec | ls | list | uninstall) __nvm_installed_nodes ;;
		(alias | unalias) __nvm_alias ;;
		(*) __nvm_commands ;;
	esac
	return 0
}
__nvm_alias () {
	__nvm_generate_completion "$(__nvm_aliases)"
}
__nvm_aliases () {
	declare aliases
	aliases="" 
	if [ -d "${NVM_DIR}/alias" ]
	then
		aliases="$(command cd "${NVM_DIR}/alias" && command find "${PWD}" -type f | command sed "s:${PWD}/::")" 
	fi
	echo "${aliases} node stable unstable iojs"
}
__nvm_commands () {
	declare current_word
	declare command
	current_word="${COMP_WORDS[COMP_CWORD]}" 
	COMMANDS='
    help install uninstall use run exec
    alias unalias reinstall-packages
    current list ls list-remote ls-remote
    install-latest-npm
    cache deactivate unload
    version version-remote which' 
	if [ ${#COMP_WORDS[@]} == 4 ]
	then
		command="${COMP_WORDS[COMP_CWORD - 2]}" 
		case "${command}" in
			(alias) __nvm_installed_nodes ;;
		esac
	else
		case "${current_word}" in
			(-*) __nvm_options ;;
			(*) __nvm_generate_completion "${COMMANDS}" ;;
		esac
	fi
}
__nvm_generate_completion () {
	declare current_word
	current_word="${COMP_WORDS[COMP_CWORD]}" 
	COMPREPLY=($(compgen -W "$1" -- "${current_word}")) 
	return 0
}
__nvm_installed_nodes () {
	__nvm_generate_completion "$(nvm_ls) $(__nvm_aliases)"
}
__nvm_options () {
	OPTIONS='' 
	__nvm_generate_completion "${OPTIONS}"
}
__zoxide_cd () {
	\builtin cd -- "$@"
}
__zoxide_hook () {
	\command zoxide add -- "$(__zoxide_pwd)"
}
__zoxide_pwd () {
	\builtin pwd -L
}
__zoxide_z () {
	if [[ "$#" -eq 0 ]]
	then
		__zoxide_cd ~
	elif [[ "$#" -eq 1 ]] && {
			[[ -d "$1" ]] || [[ "$1" = '-' ]] || [[ "$1" =~ ^[-+][0-9]$ ]]
		}
	then
		__zoxide_cd "$1"
	elif [[ "$@[-1]" == "${__zoxide_z_prefix}"?* ]]
	then
		\builtin local result="${@[-1]}"
		__zoxide_cd "${result:${#__zoxide_z_prefix}}"
	else
		\builtin local result
		result="$(\command zoxide query --exclude "$(__zoxide_pwd)" -- "$@")"  && __zoxide_cd "${result}"
	fi
}
__zoxide_zi () {
	\builtin local result
	result="$(\command zoxide query --interactive -- "$@")"  && __zoxide_cd "${result}"
}
acp () {
	local msg="${1}" 
	if [[ -z "$msg" ]]
	then
		echo "Usage: acp <commit-message>"
		return 1
	fi
	git add .
	git commit -m "$msg"
	git push
}
add-zsh-hook () {
	emulate -L zsh
	local -a hooktypes
	hooktypes=(chpwd precmd preexec periodic zshaddhistory zshexit zsh_directory_name) 
	local usage="Usage: add-zsh-hook hook function\nValid hooks are:\n  $hooktypes" 
	local opt
	local -a autoopts
	integer del list help
	while getopts "dDhLUzk" opt
	do
		case $opt in
			(d) del=1  ;;
			(D) del=2  ;;
			(h) help=1  ;;
			(L) list=1  ;;
			([Uzk]) autoopts+=(-$opt)  ;;
			(*) return 1 ;;
		esac
	done
	shift $(( OPTIND - 1 ))
	if (( list ))
	then
		typeset -mp "(${1:-${(@j:|:)hooktypes}})_functions"
		return $?
	elif (( help || $# != 2 || ${hooktypes[(I)$1]} == 0 ))
	then
		print -u$(( 2 - help )) $usage
		return $(( 1 - help ))
	fi
	local hook="${1}_functions" 
	local fn="$2" 
	if (( del ))
	then
		if (( ${(P)+hook} ))
		then
			if (( del == 2 ))
			then
				set -A $hook ${(P)hook:#${~fn}}
			else
				set -A $hook ${(P)hook:#$fn}
			fi
			if (( ! ${(P)#hook} ))
			then
				unset $hook
			fi
		fi
	else
		if (( ${(P)+hook} ))
		then
			if (( ${${(P)hook}[(I)$fn]} == 0 ))
			then
				typeset -ga $hook
				set -A $hook ${(P)hook} $fn
			fi
		else
			typeset -ga $hook
			set -A $hook $fn
		fi
		autoload $autoopts -- $fn
	fi
}
addlinenums () {
	local file="${1:--}" 
	npm list -ba "$file"
}
allhelp () {
	local help_content
	help_content=$(cat <<'EOF'
DEVELOPMENT
  devhelp      - Development workflow helpers
  gshelp       - Git shortcuts
  ghhelp       - GitHub CLI shortcuts
  perfhelp     - Performance monitoring & profiling
  pyhelp       - Python development (uv, poetry, pip, conda)
  nodehelp     - Node.js & npm shortcuts
  gohelp       - Go development tools
  cargohelp    - Cargo & Rust tools

INFRASTRUCTURE
  anshelp      - Ansible automation
  gchelp       - Google Cloud Platform
  awshelp      - AWS CLI shortcuts
  jenkinshelp  - Jenkins CI/CD
  vaulthelp    - HashiCorp Vault
  consulhelp   - HashiCorp Consul
  tfhelp       - Terraform infrastructure

CONTAINERS & ORCHESTRATION
  dshelp       - Docker shortcuts & helpers
  kbhelp       - Kubernetes (kubectl) shortcuts
  hmhelp       - Helm package manager
  vghelp       - Vagrant virtual machines

SYSTEM & NETWORK
  syshelp      - System monitoring & management
  sysdhelp     - systemd service management
  nethelp      - Network diagnostics
  sechelp      - Security & crypto tools
  tmhelp       - Tmux terminal multiplexer

DATA & APIs
  apihelp      - API testing & HTTP clients
  texthelp     - Text processing & manipulation
  dbhelp       - Database tools & helpers

BUILD & TOOLS
  makehelp     - Build systems (make, cmake, ninja)

QUICK TIPS
  helpgrep <pattern> - Search across all help
  helplist           - See all available commands
  hh <category>      - Quick access (e.g., 'hh git')
  helpbrowse         - Interactive help browser
EOF
) 
	if command -v fzf > /dev/null 2>&1
	then
		local temp_file=$(mktemp) 
		local selection
		selection=$(echo "$help_content" | fzf \
      --height 80% \
      --border \
      --prompt "Help > " \
      --header "Search and select a help category (ESC to quit)" \
      --preview 'cmd=$(echo {} | awk "{print \$1}"); if [[ -n "$cmd" ]]; then zsh -i -c "$cmd" 2>/dev/null; else echo "Preview not available"; fi' \
      --preview-window right:60% \
      --bind "enter:execute(cmd=\$(echo {} | awk \"{print \\\$1}\"); if [[ -n \"\$cmd\" ]]; then clear; export _HELP_TEMP_FILE=\"$temp_file\"; zsh -i -c \"\$cmd\"; echo; read -k 1 -s \"?Press any key to continue...\"; fi)" \
      --bind 'ctrl-r:reload(echo "$help_content")' \
      --ansi) 
		if [[ -f "$temp_file" && -s "$temp_file" ]]
		then
			local selected_cmd=$(cat "$temp_file") 
			rm -f "$temp_file"
			if [[ -n "$selected_cmd" ]]
			then
				print -z "$selected_cmd"
				echo ""
				echo "✓ Command '$selected_cmd' inserted into command line"
				echo "  (Press ENTER to execute, or edit as needed)"
			fi
		else
			rm -f "$temp_file"
		fi
	else
		batcat <<'EOF'

=====================  MASTER HELP SYSTEM  =====================

Available Help Commands (type any to see detailed shortcuts):

EOF
		echo "$help_content"
		batcat <<'EOF'

=========================================================================
Note: Install fzf for interactive searchable help
EOF
	fi
}
ansdry () {
	local playbook="${1}" 
	local inventory="${2:-inventory}" 
	if [[ -z "$playbook" ]]
	then
		echo "Usage: ansdry <playbook> [inventory-file]"
		return 1
	fi
	ansible-playbook -i "$inventory" "$playbook" --check --diff
}
ansgrpick () {
	local role
	role=$(ansible-galaxy search '' --platforms EL | grep "^  " | awk '{print $1}' \
    | fzf --height 40% --prompt "Install Galaxy Role> ")  || return
	ansible-galaxy install "$role"
}
anshelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE COMMANDS
  ans       → ansible
  ansp      → ansible-playbook
  ansi      → ansible-inventory
  ansg      → ansible-galaxy
  ansv      → ansible-vault
  ansc      → ansible-config
  ansd      → ansible-doc

PLAYBOOK EXECUTION
  anspd     → ansible-playbook --check (dry-run)
  anspc     → ansible-playbook --check --diff
  anspv     → ansible-playbook -v (verbose)
  anspvv    → ansible-playbook -vv
  anspvvv   → ansible-playbook -vvv

INVENTORY
  ansil     → ansible-inventory --list
  ansig     → ansible-inventory --graph
  ansihost X→ ansible-inventory --host X

GALAXY
  ansgi X   → ansible-galaxy install X
  ansgl     → ansible-galaxy list
  ansgr X   → ansible-galaxy remove X
  ansgs X   → ansible-galaxy search X
  ansgcr X  → ansible-galaxy collection install X
  ansgcl    → ansible-galaxy collection list

VAULT
  ansve X   → ansible-vault encrypt X
  ansvd X   → ansible-vault decrypt X
  ansvc X   → ansible-vault create X
  ansvv X   → ansible-vault view X
  ansved X  → ansible-vault edit X
  ansvr X   → ansible-vault rekey X

AD-HOC COMMANDS
  ansping   → ansible all -m ping
  anssetup  → ansible all -m setup
  anscmd X  → ansible all -a X

FZF UI HELPERS
  ansppick     → pick playbook → run
  anspdpick    → pick playbook → dry-run
  ansipick     → pick inventory → list hosts
  anshping     → pick host → ping
  anshfacts    → pick host → gather facts
  ansrpick     → pick role → view
  ansgrpick    → pick galaxy role → install
  ansrun X [Y] → run playbook X with inventory Y
  ansdry X [Y] → dry-run playbook X with inventory Y
  anstag X Y   → run playbook X with tags Y
  anslimit X Y → run playbook X limited to hosts Y
EOF
) 
	_show_help "Ansible Tools" "$help_content"
}
anshfacts () {
	local host
	host=$(ansible-inventory --list | jq -r '._meta.hostvars | keys[]' 2>/dev/null \
    | fzf --height 40% --prompt "Gather Facts> ")  || return
	ansible "$host" -m setup
}
anshping () {
	local host
	host=$(ansible-inventory --list | jq -r '._meta.hostvars | keys[]' 2>/dev/null \
    | fzf --height 40% --prompt "Ping Host> ")  || return
	ansible "$host" -m ping
}
ansipick () {
	local inv_file
	inv_file=$(find . -maxdepth 2 -name "inventory*" -o -name "hosts" | \
    fzf --height 40% --prompt "Inventory File> " \
        --preview "cat {}")  || return
	ansible-inventory -i "$inv_file" --list
}
anslimit () {
	local playbook="${1}" 
	local limit="${2}" 
	if [[ -z "$playbook" || -z "$limit" ]]
	then
		echo "Usage: anslimit <playbook> <host-pattern>"
		return 1
	fi
	ansible-playbook "$playbook" --limit "$limit"
}
anspdpick () {
	if [[ ! -d playbooks && ! -f *.yml && ! -f *.yaml ]]
	then
		echo "No playbooks found in current directory"
		return 1
	fi
	local playbook
	playbook=$(find . -maxdepth 2 -name "*.yml" -o -name "*.yaml" | grep -v 'group_vars\|host_vars\|roles' \
    | fzf --height 40% --prompt "Dry-run Playbook> " \
        --preview "bat --color=always {}")  || return
	echo "Dry-running playbook: $playbook"
	ansible-playbook "$playbook" --check --diff
}
ansppick () {
	if [[ ! -d playbooks && ! -f *.yml && ! -f *.yaml ]]
	then
		echo "No playbooks found in current directory"
		return 1
	fi
	local playbook
	playbook=$(find . -maxdepth 2 -name "*.yml" -o -name "*.yaml" | grep -v 'group_vars\|host_vars\|roles' \
    | fzf --height 40% --prompt "Playbook> " \
        --preview "bat --color=always {}")  || return
	echo "Running playbook: $playbook"
	ansible-playbook "$playbook"
}
ansrpick () {
	if [[ ! -d roles ]]
	then
		echo "No roles directory found"
		return 1
	fi
	local role
	role=$(ls -1 roles | fzf --height 40% --prompt "View Role> " \
      --preview "ls -la roles/{}")  || return
	echo "Role: $role"
	lsd -la "roles/$role"
}
ansrun () {
	local playbook="${1}" 
	local inventory="${2:-inventory}" 
	if [[ -z "$playbook" ]]
	then
		echo "Usage: ansrun <playbook> [inventory-file]"
		return 1
	fi
	ansible-playbook -i "$inventory" "$playbook"
}
anstag () {
	local playbook="${1}" 
	local tags="${2}" 
	if [[ -z "$playbook" || -z "$tags" ]]
	then
		echo "Usage: anstag <playbook> <tags>"
		return 1
	fi
	ansible-playbook "$playbook" --tags "$tags"
}
apiauth () {
	local url="${1}" 
	local token="${2}" 
	if [[ -z "$url" || -z "$token" ]]
	then
		echo "Usage: apiauth <url> <token>"
		return 1
	fi
	curl -s "$url" -H "Authorization: Bearer $token" | jq .
}
apiauthpost () {
	local url="${1}" 
	local token="${2}" 
	local data="${3}" 
	if [[ -z "$url" || -z "$token" || -z "$data" ]]
	then
		echo "Usage: apiauthpost <url> <token> <json-data>"
		return 1
	fi
	curl -X POST "$url" -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$data" | jq .
}
apibench () {
	local url="${1}" 
	local requests="${2:-100}" 
	local concurrency="${3:-10}" 
	if [[ -z "$url" ]]
	then
		echo "Usage: apibench <url> [requests] [concurrency]"
		return 1
	fi
	if command -v ab > /dev/null 2>&1
	then
		ab -n "$requests" -c "$concurrency" "$url"
	else
		echo "Apache Bench (ab) not installed. Install with: sudo dnf install httpd-tools"
	fi
}
apicompare () {
	local url1="${1}" 
	local url2="${2}" 
	if [[ -z "$url1" || -z "$url2" ]]
	then
		echo "Usage: apicompare <url1> <url2>"
		return 1
	fi
	local resp1=$(mktemp) 
	local resp2=$(mktemp) 
	curl -s "$url1" | jq . > "$resp1"
	curl -s "$url2" | jq . > "$resp2"
	diff "$resp1" "$resp2"
	rm "$resp1" "$resp2"
}
apidel () {
	local url="${1}" 
	if [[ -z "$url" ]]
	then
		echo "Usage: apidel <url>"
		return 1
	fi
	curl -X DELETE "$url" | jq .
}
apifield () {
	local url="${1}" 
	local field="${2}" 
	if [[ -z "$url" || -z "$field" ]]
	then
		echo "Usage: apifield <url> <json-field>"
		echo "Example: apifield https://api.example.com/user .data.name"
		return 1
	fi
	curl -s "$url" | jq -r "$field"
}
apiget () {
	local url="${1}" 
	if [[ -z "$url" ]]
	then
		echo "Usage: apiget <url>"
		return 1
	fi
	curl -s "$url" | jq .
}
apihealth () {
	local url="${1}" 
	if [[ -z "$url" ]]
	then
		echo "Usage: apihealth <url>"
		return 1
	fi
	echo "Checking health of $url..."
	local status=$(curl -s -o /dev/null -w "%{http_code}" "$url") 
	local time=$(curl -s -o /dev/null -w "%{time_total}" "$url") 
	echo "HTTP Status: $status"
	echo "Response Time: ${time}s"
	if [[ "$status" == "200" ]]
	then
		echo "Status: ✓ Healthy"
	else
		echo "Status: ✗ Unhealthy"
	fi
}
apihelp () {
	local help_content
	help_content=$(cat <<'EOF'
HTTP METHODS
  GET X      → curl -X GET X
  POST X     → curl -X POST X
  PUT X      → curl -X PUT X
  PATCH X    → curl -X PATCH X
  DELETE X   → curl -X DELETE X
  HEAD X     → curl -I X
  OPTIONS X  → curl -X OPTIONS X

CURL OPTIONS
  curlj      → curl with JSON content-type
  curlv      → curl verbose
  curls      → curl silent
  curli      → curl include headers
  curlL      → curl follow redirects
  curltiming → curl with detailed timing

HTTPIE (if installed)
  http X     → http X --pretty=all
  httpv X    → http X -v
  httpj X    → http X --json
  httpf X    → http X --form

UTILITIES
  jwtdecode     → decode JWT token
  prettyjson    → pretty print JSON
  urlencode X   → URL encode string X
  urldecode X   → URL decode string X
  b64enc X      → base64 encode
  b64dec X      → base64 decode

API HELPERS
  apiget X          → GET request with pretty JSON
  apipost X Y       → POST request with JSON data
  apiput X Y        → PUT request with JSON data
  apipatch X Y      → PATCH request with JSON data
  apidel X          → DELETE request
  apiauth X Y       → GET with Bearer token
  apiauthpost X Y Z → POST with Bearer token
  apitest X         → test endpoints from file
  apibench X [N] [C]→ benchmark endpoint (N requests, C concurrency)
  apimonitor X [I]  → monitor endpoint every I seconds
  apihealth X       → check API health
  apisave X Y       → download API response to file Y
  apicompare X Y    → compare two API responses
  apifield X Y      → extract JSON field Y from response
  apiupload X Y [F] → upload file Y to endpoint X
  apitemplate [M] [U] → generate API request template
EOF
) 
	_show_help "API Testing Tools" "$help_content"
}
apimonitor () {
	local url="${1}" 
	local interval="${2:-5}" 
	if [[ -z "$url" ]]
	then
		echo "Usage: apimonitor <url> [interval-seconds]"
		return 1
	fi
	echo "Monitoring $url every $interval seconds (Ctrl+C to stop)..."
	while true
	do
		local status=$(curl -s -o /dev/null -w "%{http_code}" "$url") 
		local time=$(curl -s -o /dev/null -w "%{time_total}" "$url") 
		echo "$(date '+%Y-%m-%d %H:%M:%S') - Status: $status - Time: ${time}s"
		sleep "$interval"
	done
}
apipatch () {
	local url="${1}" 
	local data="${2}" 
	if [[ -z "$url" || -z "$data" ]]
	then
		echo "Usage: apipatch <url> <json-data>"
		return 1
	fi
	curl -X PATCH "$url" -H "Content-Type: application/json" -d "$data" | jq .
}
apipost () {
	local url="${1}" 
	local data="${2}" 
	if [[ -z "$url" || -z "$data" ]]
	then
		echo "Usage: apipost <url> <json-data>"
		echo "Example: apipost https://api.example.com/users '{\"name\":\"John\"}'"
		return 1
	fi
	curl -X POST "$url" -H "Content-Type: application/json" -d "$data" | jq .
}
apiput () {
	local url="${1}" 
	local data="${2}" 
	if [[ -z "$url" || -z "$data" ]]
	then
		echo "Usage: apiput <url> <json-data>"
		return 1
	fi
	curl -X PUT "$url" -H "Content-Type: application/json" -d "$data" | jq .
}
apisave () {
	local url="${1}" 
	local output="${2}" 
	if [[ -z "$url" || -z "$output" ]]
	then
		echo "Usage: apisave <url> <output-file>"
		return 1
	fi
	curl -s "$url" | jq . > "$output"
	echo "Saved to: $output"
}
apitemplate () {
	local method="${1:-GET}" 
	local url="${2:-https://api.example.com/endpoint}" 
	batcat <<EOF
# API Request Template

## Basic Request
curl -X $method "$url"

## With JSON Data
curl -X $method "$url" \\
  -H "Content-Type: application/json" \\
  -d '{"key": "value"}'

## With Authentication
curl -X $method "$url" \\
  -H "Authorization: Bearer YOUR_TOKEN"

## With Multiple Headers
curl -X $method "$url" \\
  -H "Content-Type: application/json" \\
  -H "Authorization: Bearer YOUR_TOKEN" \\
  -H "X-Custom-Header: value" \\
  -d '{"key": "value"}'

## Save to File
curl -X $method "$url" -o response.json

## Pretty Print Response
curl -s -X $method "$url" | jq .

EOF
}
apitest () {
	local file="${1}" 
	if [[ -z "$file" || ! -f "$file" ]]
	then
		echo "Usage: apitest <endpoints-file>"
		echo "File format: METHOD URL [DATA]"
		echo "Example:"
		echo "  GET https://api.example.com/users"
		echo "  POST https://api.example.com/users {\"name\":\"John\"}"
		return 1
	fi
	while IFS= read -r line
	do
		[[ -z "$line" || "$line" =~ ^# ]] && continue
		local method=$(echo "$line" | awk '{print $1}') 
		local url=$(echo "$line" | awk '{print $2}') 
		local data=$(echo "$line" | cut -d' ' -f3-) 
		echo "=== Testing: $method $url ==="
		if [[ -n "$data" ]]
		then
			curl -X "$method" "$url" -H "Content-Type: application/json" -d "$data" -s | jq .
		else
			curl -X "$method" "$url" -s | jq .
		fi
		echo ""
	done < "$file"
}
apiupload () {
	local url="${1}" 
	local file="${2}" 
	local field="${3:-file}" 
	if [[ -z "$url" || -z "$file" ]]
	then
		echo "Usage: apiupload <url> <file> [field-name]"
		return 1
	fi
	curl -X POST "$url" -F "$field=@$file"
}
archive () {
	if [[ -z "$1" || -z "$2" ]]
	then
		echo "Usage: archive <output.tar.gz> <files...>"
		return 1
	fi
	local output="$1" 
	shift
	tar czf "$output" "$@"
	echo "Created archive: $output"
}
awsec2pick () {
	local inst
	inst=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name}' \
    --output text \
    | fzf --height 40% --ansi --prompt "EC2 Instance> " \
        --preview "aws ec2 describe-instances --instance-ids {1}" )  || return
	aws ec2 describe-instances --instance-ids "$(echo "$inst" | awk '{print $1}')"
}
awsec2start () {
	local inst
	inst=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}' \
    --output text \
    | fzf --height 40% --prompt "Start EC2> ")  || return
	aws ec2 start-instances --instance-ids "$(echo "$inst" | awk '{print $1}')"
}
awsec2stop () {
	local inst
	inst=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}' \
    --output text \
    | fzf --height 40% --prompt "Stop EC2> ")  || return
	aws ec2 stop-instances --instance-ids "$(echo "$inst" | awk '{print $1}')"
}
awshelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE
  awsls       → aws (base command)

EC2
  awec2       → aws ec2
  awec2d      → describe instances
  awec2s      → security groups
  awec2v      → vpcs

S3
  awss3       → aws s3
  awss3ls     → list buckets
  awss3cp     → copy
  awss3sync   → sync

LAMBDA
  awsl        → aws lambda
  awslf       → list functions

IAM
  awsiam      → aws iam
  awsiamu     → list users
  awsiamr     → list roles

CLOUDWATCH LOGS
  awscwl      → aws logs
  awscwlt     → aws logs tail -f

ECS / EKS
  awsecs      → aws ecs
  awsecsl     → list clusters
  awsecsls X  → list services for cluster X
  aweks       → aws eks
  aweksl      → list EKS clusters

CLOUDFORMATION
  awscf       → cloudformation
  awscfs      → list stacks

SECRETSMANAGER
  awssm       → aws secretsmanager

FZF UI HELPERS
  awsec2pick  → pick EC2 → describe
  awsec2start → pick EC2 → start
  awsec2stop  → pick EC2 → stop
  awss3pick   → pick bucket → list objects
  awss3get    → pick bucket/file → download
  awsregion   → pick AWS region → export AWS_REGION
  awsprofile  → pick AWS profile → export AWS_PROFILE

LOCALSTACK
  localstack_on  → enable LocalStack (sets AWS_ENDPOINT_URL)
  localstack_off → disable LocalStack (unsets AWS_ENDPOINT_URL)
EOF
) 
	_show_help "AWS CLI Shortcuts" "$help_content"
}
awsprofile () {
	local profile
	profile=$(aws configure list-profiles \
    | fzf --height 40% --prompt "AWS Profile> ")  || return
	export AWS_PROFILE="$profile" 
	echo "Switched to profile: $AWS_PROFILE"
}
awsregion () {
	local region
	region=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text \
    | tr '\t' '\n' | fzf --height 40%)  || return
	export AWS_REGION="$region" 
	echo "Switched to region: $AWS_REGION"
}
awss3get () {
	local bucket file
	bucket=$(aws s3 ls | awk '{print $3}' \
    | fzf --height 40% --prompt "S3 Bucket> ")  || return
	file=$(aws s3 ls "s3://$bucket" | awk '{print $4}' \
    | fzf --height 40% --prompt "File> ")  || return
	aws s3 cp "s3://$bucket/$file" .
}
awss3pick () {
	local bucket
	bucket=$(aws s3 ls | awk '{print $3}' \
    | fzf --height 40% --prompt "S3 Bucket> ")  || return
	aws s3 ls "s3://$bucket"
}
bandwidth () {
	local iface="${1:-$(ip route | grep default | awk '{print $5}')}" 
	echo "Monitoring bandwidth on $iface (Ctrl+C to stop)..."
	iftop -i "$iface" 2> /dev/null || echo "iftop not installed. Install with: sudo dnf install iftop"
}
bashcompinit () {
	# undefined
	builtin autoload -XUz
}
bedrock_off () {
	unset CLAUDE_CODE_USE_BEDROCK
	unset ANTHROPIC_MODEL
	unset ANTHROPIC_SMALL_FAST_MODEL
	echo "Bedrock mode disabled"
}
bedrock_on () {
	deepseek_off > /dev/null
	openrouter_off > /dev/null
	export CLAUDE_CODE_USE_BEDROCK="${BEDROCK_CLAUDE_CODE_USE_BEDROCK_ORIG}" 
	export ANTHROPIC_MODEL="${BEDROCK_ANTHROPIC_MODEL_ORIG}" 
	export ANTHROPIC_SMALL_FAST_MODEL="${BEDROCK_ANTHROPIC_SMALL_FAST_MODEL_ORIG}" 
	echo "Bedrock mode enabled"
}
benchops () {
	echo "Benchmarking common operations..."
	echo ""
	if ! command -v hyperfine > /dev/null 2>&1
	then
		echo "hyperfine not installed (using basic timing)"
		echo "Install: cargo install hyperfine"
		echo ""
	fi
	echo "=== Directory listing ==="
	timecmd "ls -la ~ > /dev/null"
	echo ""
	echo "=== Find files ==="
	timecmd "find ~ -maxdepth 3 -type f > /dev/null 2>&1"
	echo ""
	echo "=== Grep ==="
	timecmd "grep -r 'test' ~/.dotfiles 2>/dev/null | head -100 > /dev/null"
	echo ""
}
bigdirs () {
	local path="${1:-.}" 
	local count="${2:-10}" 
	echo "Finding largest directories in $path..."
	du -h "$path" 2> /dev/null | sort -rh | head -n "$count"
}
bigfiles () {
	local path="${1:-.}" 
	local count="${2:-10}" 
	echo "Finding largest files in $path..."
	find "$path" -type f -exec du -h {} + 2> /dev/null | sort -rh | head -n "$count"
}
buildinstall () {
	quickbuild && sudo make install
}
cargohelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE COMMANDS
  cg        → cargo
  cgb       → cargo build
  cgbr      → cargo build --release
  cgr       → cargo run
  cgrr      → cargo run --release
  cgt       → cargo test
  cgc       → cargo check
  cgcl      → cargo clean
  cgd       → cargo doc
  cgdo      → cargo doc --open

PACKAGE MANAGEMENT
  cga X     → cargo add X
  cgrm X    → cargo remove X
  cgu       → cargo update
  cgi X     → cargo install X
  cgui X    → cargo uninstall X
  cgs X     → cargo search X

PROJECT CREATION
  cgn X     → cargo new X
  cgnb X    → cargo new --bin X
  cgnl X    → cargo new --lib X
  cginit    → cargo init

FORMATTING & LINTING
  cgf       → cargo fmt
  cgfc      → cargo fmt -- --check
  cgl       → cargo clippy
  cgcla     → cargo clippy -- -W clippy::all

ADVANCED
  cgbench   → cargo bench
  cgpub     → cargo publish
  cgtr      → cargo tree

CARGO WATCH (if installed)
  cgw       → cargo watch
  cgwr      → cargo watch -x run
  cgwt      → cargo watch -x test
  cgwc      → cargo watch -x check

FZF UI HELPERS
  cgipick   → pick installed binary → run
  cguipick  → pick installed package → uninstall
  cgexpick  → pick example → run
  cgtpick   → pick test → run
  cgquick X → create new project with common deps
  cgfast    → cargo run --release (short)
  cgcheck   → fmt + clippy + check in sequence
EOF
) 
	_show_help "Cargo & Rust Tools" "$help_content"
}
cdroot () {
	local root=$(projroot) 
	if [[ $? -eq 0 ]]
	then
		cd "$root"
	fi
}
cenvpick () {
	local env
	env=$(conda env list | grep -v '^#' | awk '{print $1}' \
    | fzf --height 40% --prompt "Conda Env> ")  || return
	conda activate "$env"
}
certexpiry () {
	local cert="${1}" 
	if [[ -z "$cert" ]]
	then
		echo "Usage: certexpiry <cert-file>"
		return 1
	fi
	openssl x509 -in "$cert" -noout -dates
}
cgcheck () {
	echo "Running cargo fmt..."
	cargo fmt || return
	echo "Running cargo clippy..."
	cargo clippy -- -W clippy::all || return
	echo "Running cargo check..."
	cargo check
}
cgexpick () {
	if [[ ! -d examples ]]
	then
		echo "No examples directory found"
		return 1
	fi
	local example
	example=$(ls examples/*.rs 2>/dev/null | xargs -n1 basename | sed 's/.rs$//' \
    | fzf --height 40% --prompt "Example> " \
        --preview "cat examples/{}.rs")  || return
	cargo run --example "$example"
}
cgfast () {
	cargo run --release "$@"
}
cgipick () {
	local bin
	bin=$(cargo install --list | grep '^[a-z]' | awk '{print $1}' \
    | fzf --height 40% --prompt "Cargo Binary> ")  || return
	echo "Running: $bin"
	"$bin"
}
cgquick () {
	local name="${1}" 
	if [[ -z "$name" ]]
	then
		echo "Usage: cgquick <project-name>"
		return 1
	fi
	cargo new "$name"
	cd "$name" || return
	cargo add serde --features derive
	cargo add tokio --features full
	cargo add anyhow
	echo "Created Rust project '$name' with common dependencies"
}
cgtpick () {
	local test
	test=$(cargo test -- --list 2>/dev/null | grep ': test$' | sed 's/: test$//' \
    | fzf --height 40% --prompt "Test> ")  || return
	cargo test "$test"
}
cguipick () {
	local pkg
	pkg=$(cargo install --list | grep '^[a-z]' | awk '{print $1}' \
    | fzf --height 40% --prompt "Uninstall Package> ")  || return
	cargo uninstall "$pkg"
}
checkport () {
	local host="${1}" 
	local port="${2}" 
	if [[ -z "$host" || -z "$port" ]]
	then
		echo "Usage: checkport <host> <port>"
		return 1
	fi
	if ninja -C build clean -z -w 2 "$host" "$port" 2> /dev/null
	then
		echo "Port $port on $host is OPEN"
	else
		echo "Port $port on $host is CLOSED"
	fi
}
cintpick () {
	local intention
	intention=$(consul intention list -format=json | jq -r '.[] | "\(.SourceName) → \(.DestinationName)"' \
    | fzf --height 40% --prompt "Intention> ")  || return
	echo "$intention"
}
ckget () {
	local key="${1}" 
	if [[ -z "$key" ]]
	then
		echo "Usage: ckget <key>"
		return 1
	fi
	consul kv get "$key"
}
ckput () {
	local key="${1}" 
	local value="${2}" 
	if [[ -z "$key" || -z "$value" ]]
	then
		echo "Usage: ckput <key> <value>"
		return 1
	fi
	consul kv put "$key" "$value"
}
ckvdelpick () {
	local key
	key=$(consul kv get -keys '' | sed 's|/$||' \
    | fzf --height 40% --prompt "Delete Key> ")  || return
	echo "Delete key: $key?"
	read "?Confirm (y/N): " answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		consul kv delete "$key"
	else
		echo "Cancelled"
	fi
}
ckvexport () {
	local prefix="${1}" 
	if [[ -z "$prefix" ]]
	then
		echo "Usage: ckvexport <key-prefix>"
		return 1
	fi
	consul kv export "$prefix"
}
ckvimport () {
	local file="${1}" 
	if [[ -z "$file" || ! -f "$file" ]]
	then
		echo "Usage: ckvimport <json-file>"
		return 1
	fi
	consul kv import @"$file"
}
ckvpick () {
	local key
	key=$(consul kv get -keys '' | sed 's|/$||' \
    | fzf --height 40% --prompt "KV Key> " \
        --preview "consul kv get {}")  || return
	consul kv get "$key"
}
claudehelp () {
	batcat <<'EOF'

===================  CLAUDE CODE ENVIRONMENT TOGGLES  ===================

BEDROCK
  bedrock_on   → enable AWS Bedrock Claude (sets CLAUDE_CODE_USE_BEDROCK, ANTHROPIC_MODEL)
  bedrock_off  → disable AWS Bedrock Claude

DEEPSEEK
  deepseek_on  → enable DeepSeek API (sets ANTHROPIC_BASE_URL, API_TIMEOUT_MS, etc.)
  deepseek_off → disable DeepSeek API
  dsh <prompt> → launch DeepSeek harness headless (npx @deepseek-ai/dsh --profile headless)

OPENROUTER
  openrouter_on              → enable OpenRouter API (requires OPENROUTER_API_KEY env var)
  openrouter_off             → disable OpenRouter API
  openrouter_set_model       → set model overrides for sonnet/opus/haiku/fable tiers
                               Usage: openrouter_set_model <tier> <model-name>
                               Example: openrouter_set_model sonnet ~anthropic/claude-sonnet-latest
  openrouter_fzf             → interactive model selection with fzf (requires fzf installed)

ISOLATED CONFIG / ACCOUNTS  (bin/claude-local)
  claude-local                     → per-project config dir: $PWD/.claude
  claude-local --profile NAME       → isolated account: ~/.claude-profiles/NAME
                                      Own credentials, MCP servers and history.
                                      Seeded from ~/.claude on first use.
  claude-local --list               → list profiles and which account each uses
  claude-local --help               → full usage
  claude-local --profile NAME --keep-env
                                    → keep the toggles above instead of scrubbing them

NOTES
  - All modes are OFF by default
  - Only enable one mode at a time
  - Use *_off commands to return to default Anthropic API
  - For OpenRouter: Set OPENROUTER_API_KEY before running openrouter_on
  - claude-local --profile unsets the vars set by the toggles above, so a stale
    bedrock_on/openrouter_on cannot override a profile's own login

=========================================================================

EOF
}
cleancache () {
	echo "Cleaning package cache..."
	if command -v apt-get > /dev/null 2>&1
	then
		sudo apt-get clean
		sudo apt-get autoclean
		sudo apt-get autoremove
	elif command -v yum > /dev/null 2>&1
	then
		sudo yum clean all
	elif command -v dnf > /dev/null 2>&1
	then
		sudo dnf clean all
	fi
	echo "Cache cleaned"
}
clearcache () {
	echo "Clearing various caches..."
	echo ""
	echo "=== Zsh completion cache ==="
	if [[ -f "$HOME/.zcompdump" ]]
	then
		rm -f "$HOME/.zcompdump*"
		echo "Cleared .zcompdump"
	fi
	echo ""
	echo "=== Package manager caches ==="
	echo "Run manually if needed:"
	echo "  sudo apt clean              # APT cache"
	echo "  conda clean --all           # Conda cache"
	echo "  npm cache clean --force     # NPM cache"
	echo "  cargo cache --autoclean     # Cargo cache"
	echo "  pip cache purge             # Pip cache"
	echo ""
	echo "=== System memory cache (requires sudo) ==="
	echo "Run manually if needed:"
	echo "  sudo sync && sudo sysctl -w vm.drop_caches=3"
}
cmbuild () {
	local build_type="${1:-Release}" 
	cmake -S . -B build -DCMAKE_BUILD_TYPE="$build_type"
	cmake --build build
}
cmclean () {
	rm -rf build
	cmbuild "${1:-Release}"
}
cmdhelp () {
	local cmd="${1}" 
	if [[ -z "$cmd" ]]
	then
		echo "Usage: cmdhelp <command>"
		echo "Example: cmdhelp gs"
		return 1
	fi
	local alias_def=$(alias "$cmd" 2>/dev/null) 
	if [[ -n "$alias_def" ]]
	then
		echo "Alias: $alias_def"
	fi
	if command -v "$cmd" > /dev/null 2>&1
	then
		local func_type=$(type -w "$cmd" 2>/dev/null | awk '{print $2}') 
		if [[ "$func_type" == "function" ]]
		then
			echo "Function:"
			type "$cmd" | tail -n +2
		fi
	fi
	echo ""
	echo "Help references:"
	helpgrep "$cmd" | head -20
}
cmninja () {
	local build_type="${1:-Release}" 
	cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE="$build_type"
	ninja -C build
}
cnpick () {
	local node
	node=$(consul catalog nodes -detailed | awk '{print $1}' \
    | fzf --height 40% --prompt "Node> " \
        --preview "consul catalog nodes -detailed | grep {}")  || return
	consul members | grep "$node"
}
colstats () {
	local col="${1:-1}" 
	local file="${2:--}" 
	awk -v col="$col" '{sum+=$col; sumsq+=$col*$col; if(NR==1){min=max=$col}}
       $col<min{min=$col} $col>max{max=$col}
       END{print "Count:", NR; print "Sum:", sum; print "Mean:", sum/NR;
           print "Min:", min; print "Max:", max}' "$file"
}
compaudit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/functions/Completion
}
compdef () {
	local opt autol type func delete eval new i ret=0 cmd svc 
	local -a match mbegin mend
	emulate -L zsh
	setopt extendedglob
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	while getopts "anpPkKde" opt
	do
		case "$opt" in
			(a) autol=yes  ;;
			(n) new=yes  ;;
			([pPkK]) if [[ -n "$type" ]]
				then
					print -u2 "$0: type already set to $type"
					return 1
				fi
				if [[ "$opt" = p ]]
				then
					type=pattern 
				elif [[ "$opt" = P ]]
				then
					type=postpattern 
				elif [[ "$opt" = K ]]
				then
					type=widgetkey 
				else
					type=key 
				fi ;;
			(d) delete=yes  ;;
			(e) eval=yes  ;;
		esac
	done
	shift OPTIND-1
	if (( ! $# ))
	then
		print -u2 "$0: I need arguments"
		return 1
	fi
	if [[ -z "$delete" ]]
	then
		if [[ -z "$eval" ]] && [[ "$1" = *\=* ]]
		then
			while (( $# ))
			do
				if [[ "$1" = *\=* ]]
				then
					cmd="${1%%\=*}" 
					svc="${1#*\=}" 
					func="$_comps[${_services[(r)$svc]:-$svc}]" 
					[[ -n ${_services[$svc]} ]] && svc=${_services[$svc]} 
					[[ -z "$func" ]] && func="${${_patcomps[(K)$svc][1]}:-${_postpatcomps[(K)$svc][1]}}" 
					if [[ -n "$func" ]]
					then
						_comps[$cmd]="$func" 
						_services[$cmd]="$svc" 
					else
						print -u2 "$0: unknown command or service: $svc"
						ret=1 
					fi
				else
					print -u2 "$0: invalid argument: $1"
					ret=1 
				fi
				shift
			done
			return ret
		fi
		func="$1" 
		[[ -n "$autol" ]] && autoload -rUz "$func"
		shift
		case "$type" in
			(widgetkey) while [[ -n $1 ]]
				do
					if [[ $# -lt 3 ]]
					then
						print -u2 "$0: compdef -K requires <widget> <comp-widget> <key>"
						return 1
					fi
					[[ $1 = _* ]] || 1="_$1" 
					[[ $2 = .* ]] || 2=".$2" 
					[[ $2 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$1" "$2" "$func"
					if [[ -n $new ]]
					then
						bindkey "$3" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] && bindkey "$3" "$1"
					else
						bindkey "$3" "$1"
					fi
					shift 3
				done ;;
			(key) if [[ $# -lt 2 ]]
				then
					print -u2 "$0: missing keys"
					return 1
				fi
				if [[ $1 = .* ]]
				then
					[[ $1 = .menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" "$1" "$func"
				else
					[[ $1 = menu-select ]] && zmodload -i zsh/complist
					zle -C "$func" ".$1" "$func"
				fi
				shift
				for i
				do
					if [[ -n $new ]]
					then
						bindkey "$i" | IFS=$' \t' read -A opt
						[[ $opt[-1] = undefined-key ]] || continue
					fi
					bindkey "$i" "$func"
				done ;;
			(*) while (( $# ))
				do
					if [[ "$1" = -N ]]
					then
						type=normal 
					elif [[ "$1" = -p ]]
					then
						type=pattern 
					elif [[ "$1" = -P ]]
					then
						type=postpattern 
					else
						case "$type" in
							(pattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_patcomps[$match[1]]="=$match[2]=$func" 
								else
									_patcomps[$1]="$func" 
								fi ;;
							(postpattern) if [[ $1 = (#b)(*)=(*) ]]
								then
									_postpatcomps[$match[1]]="=$match[2]=$func" 
								else
									_postpatcomps[$1]="$func" 
								fi ;;
							(*) if [[ "$1" = *\=* ]]
								then
									cmd="${1%%\=*}" 
									svc=yes 
								else
									cmd="$1" 
									svc= 
								fi
								if [[ -z "$new" || -z "${_comps[$1]}" ]]
								then
									_comps[$cmd]="$func" 
									[[ -n "$svc" ]] && _services[$cmd]="${1#*\=}" 
								fi ;;
						esac
					fi
					shift
				done ;;
		esac
	else
		case "$type" in
			(pattern) unset "_patcomps[$^@]" ;;
			(postpattern) unset "_postpatcomps[$^@]" ;;
			(key) print -u2 "$0: cannot restore key bindings"
				return 1 ;;
			(*) unset "_comps[$^@]" ;;
		esac
	fi
}
compdump () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/functions/Completion
}
compgen () {
	local opts prefix suffix job OPTARG OPTIND ret=1 
	local -a name res results jids
	local -A shortopts
	emulate -L sh
	setopt kshglob noshglob braceexpand nokshautoload
	shortopts=(a alias b builtin c command d directory e export f file g group j job k keyword u user v variable) 
	while getopts "o:A:G:C:F:P:S:W:X:abcdefgjkuv" name
	do
		case $name in
			([abcdefgjkuv]) OPTARG="${shortopts[$name]}"  ;&
			(A) case $OPTARG in
					(alias) results+=("${(k)aliases[@]}")  ;;
					(arrayvar) results+=("${(k@)parameters[(R)array*]}")  ;;
					(binding) results+=("${(k)widgets[@]}")  ;;
					(builtin) results+=("${(k)builtins[@]}" "${(k)dis_builtins[@]}")  ;;
					(command) results+=("${(k)commands[@]}" "${(k)aliases[@]}" "${(k)builtins[@]}" "${(k)functions[@]}" "${(k)reswords[@]}")  ;;
					(directory) setopt bareglobqual
						results+=(${IPREFIX}${PREFIX}*${SUFFIX}${ISUFFIX}(N-/)) 
						setopt nobareglobqual ;;
					(disabled) results+=("${(k)dis_builtins[@]}")  ;;
					(enabled) results+=("${(k)builtins[@]}")  ;;
					(export) results+=("${(k)parameters[(R)*export*]}")  ;;
					(file) setopt bareglobqual
						results+=(${IPREFIX}${PREFIX}*${SUFFIX}${ISUFFIX}(N)) 
						setopt nobareglobqual ;;
					(function) results+=("${(k)functions[@]}")  ;;
					(group) emulate zsh
						_groups -U -O res
						emulate sh
						setopt kshglob noshglob braceexpand
						results+=("${res[@]}")  ;;
					(hostname) emulate zsh
						_hosts -U -O res
						emulate sh
						setopt kshglob noshglob braceexpand
						results+=("${res[@]}")  ;;
					(job) results+=("${savejobtexts[@]%% *}")  ;;
					(keyword) results+=("${(k)reswords[@]}")  ;;
					(running) jids=("${(@k)savejobstates[(R)running*]}") 
						for job in "${jids[@]}"
						do
							results+=(${savejobtexts[$job]%% *}) 
						done ;;
					(stopped) jids=("${(@k)savejobstates[(R)suspended*]}") 
						for job in "${jids[@]}"
						do
							results+=(${savejobtexts[$job]%% *}) 
						done ;;
					(setopt | shopt) results+=("${(k)options[@]}")  ;;
					(signal) results+=("SIG${^signals[@]}")  ;;
					(user) results+=("${(k)userdirs[@]}")  ;;
					(variable) results+=("${(k)parameters[@]}")  ;;
					(helptopic)  ;;
				esac ;;
			(F) COMPREPLY=() 
				local -a args
				args=("${words[0]}" "${@[-1]}" "${words[CURRENT-2]}") 
				() {
					typeset -h words
					$OPTARG "${args[@]}"
				}
				results+=("${COMPREPLY[@]}")  ;;
			(G) setopt nullglob
				results+=(${~OPTARG}) 
				unsetopt nullglob ;;
			(W) results+=(${(Q)~=OPTARG})  ;;
			(C) results+=($(eval $OPTARG))  ;;
			(P) prefix="$OPTARG"  ;;
			(S) suffix="$OPTARG"  ;;
			(X) if [[ ${OPTARG[0]} = '!' ]]
				then
					results=("${(M)results[@]:#${OPTARG#?}}") 
				else
					results=("${results[@]:#$OPTARG}") 
				fi ;;
		esac
	done
	print -l -r -- "$prefix${^results[@]}$suffix"
}
compinit () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/functions/Completion
}
compinstall () {
	# undefined
	builtin autoload -XUz /usr/share/zsh/functions/Completion
}
complete () {
	emulate -L zsh
	local args void cmd print remove
	args=("$@") 
	zparseopts -D -a void o: A: G: W: C: F: P: S: X: a b c d e f g j k u v p=print r=remove
	if [[ -n $print ]]
	then
		printf 'complete %2$s %1$s\n' "${(@kv)_comps[(R)_bash*]#* }"
	elif [[ -n $remove ]]
	then
		for cmd
		do
			unset "_comps[$cmd]"
		done
	else
		compdef _bash_complete\ ${(j. .)${(q)args[1,-1-$#]}} "$@"
	fi
}
conda () {
	\local cmd="${1-__missing__}"
	case "$cmd" in
		(activate | deactivate) __conda_activate "$@" ;;
		(install | update | upgrade | remove | uninstall) __conda_exe "$@" || \return
			__conda_activate reactivate ;;
		(*) __conda_exe "$@" ;;
	esac
}
connpick () {
	local conn
	conn=$(ss -tunp | grep ESTAB \
    | fzf --height 40% --prompt "Connection> ")  || return
	echo "$conn"
}
consulhelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE OPERATIONS
  c         → consul
  cm        → consul members
  ci        → consul info
  cj X      → consul join X
  cl        → consul leave

AGENT
  ca        → consul agent
  cad       → consul agent -dev (dev mode)
  car       → consul reload

SERVICES
  cs        → consul services
  csr X     → consul services register X
  csd X     → consul services deregister X

CATALOG
  ccat      → consul catalog
  ccats     → consul catalog services
  ccatn     → consul catalog nodes
  ccatd     → consul catalog datacenters

KV (KEY-VALUE)
  ckv       → consul kv
  ckvg X    → consul kv get X
  ckvp X Y  → consul kv put X Y
  ckvl X    → consul kv delete X
  ckvls     → consul kv get -keys ''

HEALTH
  ch        → consul health
  chs X     → consul health service X
  chn X     → consul health node X
  chc X     → consul health checks X

EVENTS
  ce        → consul event
  cef X     → consul event fire X
  cel       → consul event list

INTENTIONS
  cint      → consul intention
  cintc     → consul intention create
  cintd     → consul intention delete
  cintl     → consul intention list
  cintm     → consul intention match

CONFIG
  cconf     → consul config
  cconfl    → consul config list
  cconfr X  → consul config read X
  cconfw X  → consul config write X
  cconfd X  → consul config delete X

ACL
  cacl      → consul acl
  caclp     → consul acl policy
  caclt     → consul acl token
  caclr     → consul acl role

SNAPSHOT
  csnap     → consul snapshot
  csnaps X  → consul snapshot save X
  csnapr X  → consul snapshot restore X

WATCH
  cw        → consul watch
  cwk X     → consul watch key X
  cws X     → consul watch service X
  cwn       → consul watch nodes

FZF UI HELPERS
  cspick        → pick service → view health
  cnpick        → pick node → view details
  ckvpick       → pick KV key → get value
  ckvdelpick    → pick KV key → delete
  cwspick       → pick service → watch
  cintpick      → pick intention → view
  ckput X Y     → quick kv put
  ckget X       → quick kv get
  csreg X Y     → quick service register (name, port)
  csdereg X     → quick service deregister
  cshealthall   → list all services with health
  ckvexport X   → export KV tree as JSON
  ckvimport X   → import KV tree from JSON
  csnapsave [X] → quick snapshot save
  cwservice X Y → watch service X, execute command Y
EOF
) 
	_show_help "HashiCorp Consul" "$help_content"
}
countpattern () {
	local pattern="${1}" 
	local file="${2}" 
	if [[ -z "$pattern" || -z "$file" ]]
	then
		echo "Usage: countpattern <pattern> <file>"
		return 1
	fi
	grep -o "$pattern" "$file" | wc -l
}
cpucores () {
	if command -v mpstat > /dev/null 2>&1
	then
		mpstat -P ALL 2 5
	else
		echo "mpstat not installed"
		echo "Install with: sudo dnf install sysstat"
		echo ""
		echo "Showing CPU info instead:"
		lscpu
	fi
}
cpv () {
	if ! command -v rsync > /dev/null 2>&1
	then
		echo "rsync not installed. Falling back to cp"
		xcp -r "$@"
		return
	fi
	rsync -ah --info=progress2 "$@"
}
createchecksum () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		echo "Usage: createchecksum <file>"
		return 1
	fi
	sha256sum "$file" > "${file}.sha256"
	echo "Created: ${file}.sha256"
}
csdereg () {
	local name="${1}" 
	if [[ -z "$name" ]]
	then
		echo "Usage: csdereg <service-name>"
		return 1
	fi
	consul services deregister "$name"
	echo "Deregistered service: $name"
}
cshealthall () {
	echo "=== All Services with Health Status ==="
	local services=$(consul catalog services | awk '{print $1}') 
	for service in ${(f)services}
	do
		echo "\nService: $service"
		consul health service "$service" | grep -E "Node|Status|Service" | head -5
	done
}
csnapsave () {
	local filename="${1:-consul-snapshot-$(date +%Y%m%d-%H%M%S).snap}" 
	consul snapshot save "$filename"
	echo "Snapshot saved: $filename"
}
cspick () {
	local service
	service=$(consul catalog services | awk '{print $1}' \
    | fzf --height 40% --prompt "Service> " \
        --preview "consul health service {}")  || return
	consul health service "$service"
}
csreg () {
	local name="${1}" 
	local port="${2}" 
	if [[ -z "$name" || -z "$port" ]]
	then
		echo "Usage: csreg <service-name> <port>"
		return 1
	fi
	batcat > "/tmp/consul-service-${name}.json" <<EOF
{
  "service": {
    "name": "${name}",
    "port": ${port},
    "check": {
      "http": "http://localhost:${port}/health",
      "interval": "10s"
    }
  }
}
EOF
	consul services register "/tmp/consul-service-${name}.json"
	echo "Registered service: $name on port $port"
}
csvcolumn () {
	local col="${1}" 
	local file="${2}" 
	if [[ -z "$col" || -z "$file" ]]
	then
		echo "Usage: csvcolumn <column-number> <csv-file>"
		return 1
	fi
	cut -d, -f"$col" "$file"
}
cwservice () {
	local service="${1}" 
	local command="${2}" 
	if [[ -z "$service" || -z "$command" ]]
	then
		echo "Usage: cwservice <service-name> <command>"
		return 1
	fi
	consul watch -type=service -service="$service" "$command"
}
cwspick () {
	local service
	service=$(consul catalog services \
    | awk '{print $1}' \
    | fzf --height 40% --prompt "Watch Service> ")  || return
	echo "Watching service: $service (Ctrl+C to stop)"
	consul watch -type=service -service="$service" cat
}
dbhelp () {
	local help_content
	help_content=$(cat <<'EOF'
POSTGRESQL
  pg        → psql
  pglist    → psql -l (list databases)
  pgdump    → pg_dump
  pgrestore → pg_restore
  pgstart   → start postgresql service
  pgstop    → stop postgresql service
  pgrestart → restart postgresql service
  pgstatus  → status postgresql service
  pglocalhost → connect to localhost postgres

MYSQL
  my        → mysql
  mylist    → show databases
  mydump    → mysqldump
  mystart   → start mysql service
  mystop    → stop mysql service
  myrestart → restart mysql service
  mystatus  → status mysql service
  mylocalhost → connect to localhost mysql

REDIS
  red       → redis-cli
  redstart  → start redis service
  redstop   → stop redis service
  redstatus → status redis service

MONGODB
  mgo       → mongosh
  mgostart  → start mongod service
  mgostop   → stop mongod service
  mgostatus → status mongod service

FZF UI HELPERS (PostgreSQL)
  pgpick     → pick database → connect
  pgdumppick → pick database → dump to file
  pgcreate X → create database X
  pgdrop X   → drop database X (with confirmation)
  pgtables [db] → show table sizes

FZF UI HELPERS (MySQL)
  mypick     → pick database → connect
  mydumppick → pick database → dump to file
  mycreate X → create database X
  mydrop X   → drop database X (with confirmation)
  mytables X → show table sizes for database X
EOF
) 
	_show_help "Database Tools" "$help_content"
}
dcsh () {
	local cid
	cid=$(docker ps --format '{{.ID}}\t{{.Names}}' \
    | fzf --height 40% --ansi --preview "docker logs --tail 50 {1}")  || return
	docker exec -it "$(echo "$cid" | cut -f1)" sh
}
decfile () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		echo "Usage: decfile <encrypted-file>"
		return 1
	fi
	local output="${file%.enc}" 
	openssl enc -aes-256-cbc -pbkdf2 -d -in "$file" -out "$output"
	echo "Decrypted: $output"
}
dedup () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		awk '!seen[$0]++'
	else
		awk '!seen[$0]++' "$file"
	fi
}
deepseek_off () {
	unset ANTHROPIC_BASE_URL
	unset API_TIMEOUT_MS
	unset ANTHROPIC_MODEL
	unset ANTHROPIC_SMALL_FAST_MODEL
	unset CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
	echo "DeepSeek mode disabled"
}
deepseek_on () {
	bedrock_off > /dev/null
	openrouter_off > /dev/null
	export ANTHROPIC_BASE_URL="${DEEPSEEK_ANTHROPIC_BASE_URL_ORIG}" 
	export API_TIMEOUT_MS="${DEEPSEEK_API_TIMEOUT_MS_ORIG}" 
	export ANTHROPIC_MODEL="${DEEPSEEK_ANTHROPIC_MODEL_ORIG}" 
	export ANTHROPIC_SMALL_FAST_MODEL="${DEEPSEEK_ANTHROPIC_SMALL_FAST_MODEL_ORIG}" 
	export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${DEEPSEEK_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC_ORIG}" 
	echo "DeepSeek mode enabled"
}
devhelp () {
	local help_content
	help_content=$(cat <<'EOF'
PROJECT MANAGEMENT
  newproject X [T]  → create new project (types: python, node, go, rust)
  mcd X             → mkdir + cd in one command
  proj              → open project files in $EDITOR
  projroot          → show project root directory
  cdroot            → cd to project root

FILE OPERATIONS
  cpv X Y           → copy with progress bar (rsync)
  extract X         → extract any archive format
  archive X.tar.gz Y → create tar.gz archive
  ff X              → find files by name (case-insensitive)
  fif X             → find pattern in files (grep recursive)

GIT SHORTCUTS
  qc                → quick commit (interactive staging)
  acp "msg"         → add, commit, push in one command

PROCESS MANAGEMENT
  killport X        → kill process on port X
  pskill            → interactive process killer (fzf)
  portslist         → detailed list of all listening ports (lsof)
  toppid [cpu|mem]  → show top processes by CPU or memory

SERVER & UTILITIES
  serve [port] [dir] → start HTTP server (default: port 8000, cwd)
  watchhl [N] <cmd>  → watch command with highlighted changes
  randstr [N] [chars]→ generate random string
EOF
) 
	_show_help "Development Tools" "$help_content"
}
digfull () {
	local domain="${1}" 
	if [[ -z "$domain" ]]
	then
		echo "Usage: digfull <domain>"
		return 1
	fi
	echo "=== A Records ==="
	dig +short A "$domain"
	echo "\n=== AAAA Records ==="
	dig +short AAAA "$domain"
	echo "\n=== MX Records ==="
	dig +short MX "$domain"
	echo "\n=== NS Records ==="
	dig +short NS "$domain"
	echo "\n=== TXT Records ==="
	dig +short TXT "$domain"
}
dlg () {
	local cid
	cid=$(docker ps -a --format '{{.ID}}\t{{.Names}}' \
    | fzf --height 40% --preview "docker logs --tail 100 {1}")  || return
	docker logs -f "$(echo "$cid" | cut -f1)"
}
dnuke () {
	echo "☢️  WARNING: This will stop and remove ALL containers, networks, and volumes"
	read -q "REPLY?Continue? (y/n) " && echo
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		docker stop $(docker ps -q) 2> /dev/null || true
		docker rm -f $(docker ps -aq) 2> /dev/null || true
		docker network ls --filter type=custom -q | xargs -r docker network rm
		docker volume ls -q | xargs -r docker volume rm
		echo "✅ Docker nuked successfully"
	else
		echo "❌ Aborted"
	fi
}
dri () {
	local img
	img=$(docker images --format '{{.Repository}}:{{.Tag}}\t{{.ID}}' \
    | fzf --height 30%)  || return
	docker rmi "$(echo "$img" | cut -f2)"
}
dsh () {
	npx @deepseek-ai/dsh --profile headless "$*"
}
dshelp () {
	local help_content
	help_content=$(cat <<'EOF'
CONTAINERS
  dps       → docker ps (running)
  dpsa      → docker ps -a (all)
  dstart X  → docker start X
  dstop X   → docker stop X
  drm X     → docker rm X
  drmi X    → docker rmi X

IMAGES
  dim       → docker images
  dima      → docker images -a
  dpull X   → docker pull X
  dbuild X  → docker build -t X .
  drun X    → docker run -it --rm X

LOGS / EXEC
  dlog X    → docker logs -f X
  dexec X   → docker exec -it X sh

VOLUMES / NETWORK
  dvl       → docker volume ls
  dvp       → docker volume prune
  dnet      → docker network ls
  dnpr      → docker network prune

SYSTEM CLEANUP
  dprune    → docker system prune -f
  dpruneall → docker system prune -a -f
  dnuke     → ☢️  NUKE: stop/rm ALL containers, networks, volumes

FZF UI HELPERS
  dcsh      → pick running container → exec sh
  dlg       → pick any container → view logs
  dst       → pick container → stop
  dsrm      → pick container → stop & remove
  dri       → pick image → remove
EOF
) 
	_show_help "Docker Shortcuts" "$help_content"
}
dsrm () {
	local cid
	cid=$(docker ps --format '{{.ID}}\t{{.Names}}' \
    | fzf --height 30%)  || return
	local container_id=$(echo "$cid" | cut -f1) 
	docker stop "$container_id" && docker rm "$container_id"
}
dst () {
	local cid
	cid=$(docker ps --format '{{.ID}}\t{{.Names}}' \
    | fzf --height 30%)  || return
	docker stop "$(echo "$cid" | cut -f1)"
}
encfile () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		echo "Usage: encfile <file>"
		return 1
	fi
	openssl enc -aes-256-cbc -pbkdf2 -salt -in "$file" -out "${file}.enc"
	echo "Encrypted: ${file}.enc"
}
extract () {
	if [[ -z "$1" ]]
	then
		echo "Usage: extract <archive-file>"
		return 1
	fi
	if [[ ! -f "$1" ]]
	then
		echo "File not found: $1"
		return 1
	fi
	case "$1" in
		(*.tar.bz2) tar xjf "$1" ;;
		(*.tar.gz) tar xzf "$1" ;;
		(*.tar.xz) tar xJf "$1" ;;
		(*.bz2) bunzip2 "$1" ;;
		(*.rar) unrar x "$1" ;;
		(*.gz) gunzip "$1" ;;
		(*.tar) tar xf "$1" ;;
		(*.tbz2) tar xjf "$1" ;;
		(*.tgz) tar xzf "$1" ;;
		(*.zip) unzip "$1" ;;
		(*.Z) uncompress "$1" ;;
		(*.7z) 7z x "$1" ;;
		(*) echo "Don't know how to extract '$1'" ;;
	esac
}
extractemails () {
	local file="${1:--}" 
	grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b" "$file"
}
extracturls () {
	local file="${1:--}" 
	grep -E -o "(http|https)://[a-zA-Z0-9./?=_%:-]*" "$file"
}
ff () {
	local name="${1}" 
	if [[ -z "$name" ]]
	then
		echo "Usage: ff <filename-pattern>"
		return 1
	fi
	find . -iname "*$name*" 2> /dev/null
}
fif () {
	local pattern="${1}" 
	if [[ -z "$pattern" ]]
	then
		echo "Usage: fif <search-pattern>"
		return 1
	fi
	grep -rinI "$pattern" . 2> /dev/null
}
findslow () {
	echo "Finding files that might slow down shell startup..."
	echo ""
	echo "=== Large files in home directory ==="
	find ~ -maxdepth 1 -type f -size +1M 2> /dev/null | while read file
	do
		lsd -lh "$file"
	done
	echo ""
	echo "=== Large history files ==="
	find ~ -name "*history*" -type f 2> /dev/null | while read file
	do
		lsd -lh "$file"
	done
	echo ""
	echo "=== Files in .zshrc.d ==="
	if [[ -d "$HOME/.dotfiles/zshrc.d" ]]
	then
		du -h "$HOME/.dotfiles/zshrc.d"/*.zsh | sort -rh
	fi
}
gac () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	local files=$(git status --short | fzf -m --height 60% --prompt "Stage files> " \
    --header "Select files to stage (Tab to select multiple, Enter to confirm)" \
    --preview 'if [[ {1} == "??" ]]; then bat --color=always {2}; else git diff --color=always {2}; fi' \
    | awk '{print $2}') 
	if [[ -n "$files" ]]
	then
		echo "$files" | xargs git add
		echo "Staged files:"
		echo "$files"
		echo ""
		git commit
	else
		echo "No files selected"
	fi
}
gamend () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	echo "Current changes:"
	git diff --stat
	echo ""
	echo -n "Amend these changes to last commit? (y/N): "
	read answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		git add -u
		git commit --amend --no-edit
		echo "Amended to last commit"
	else
		echo "Cancelled"
	fi
}
gbr () {
	local branch
	branch=$(git branch --all --color=always | sed 's/^..//' \
    | fzf --height 40% --ansi --preview \
      "git log --oneline --graph --decorate --color=always '{}'" )  || return
	git checkout "$(echo $branch | sed 's#remotes/[^/]*/##')"
}
gcbpick () {
	local bucket
	bucket=$(gsutil ls | sed 's|gs://||; s|/$||' \
    | fzf --height 40% --prompt "List Bucket> " \
        --preview "gsutil ls -L gs://{}")  || return
	gsutil ls -l "gs://$bucket"
}
gcdelpick () {
	local instance
	instance=$(gcloud compute instances list --format="value(name,zone)" \
    | fzf --height 40% --prompt "Delete Instance> ")  || return
	local inst_name=$(echo "$instance" | awk '{print $1}') 
	local inst_zone=$(echo "$instance" | awk '{print $2}') 
	echo "Delete instance $inst_name?"
	read "?Confirm (y/N): " answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		gcloud compute instances delete "$inst_name" --zone="$inst_zone"
	else
		echo "Cancelled"
	fi
}
gcgkepick () {
	local cluster
	cluster=$(gcloud container clusters list --format="value(name,location)" \
    | fzf --height 40% --prompt "Get GKE Credentials> " \
        --preview "gcloud container clusters describe {1} --location {2}")  || return
	local cluster_name=$(echo "$cluster" | awk '{print $1}') 
	local cluster_zone=$(echo "$cluster" | awk '{print $2}') 
	gcloud container clusters get-credentials "$cluster_name" --location="$cluster_zone"
	echo "Credentials configured for: $cluster_name"
}
gchelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE
  gci       → gcloud init
  gcconf    → gcloud config

CONFIG
  gccl      → gcloud config list
  gccs X Y  → gcloud config set X Y
  gccu X    → gcloud config unset X
  gccc      → gcloud config configurations

AUTH
  gcal      → gcloud auth login
  gcalr     → gcloud auth login --remote-bootstrap
  gcala     → gcloud auth application-default login
  gcall     → gcloud auth list

COMPUTE INSTANCES
  gccmi     → gcloud compute instances
  gccmil    → list instances
  gccmic X  → create instance X
  gccmid X  → delete instance X
  gccmis X  → start instance X
  gccmist X → stop instance X
  gccmissh X→ ssh to instance X

GKE (KUBERNETES)
  gcgke     → gcloud container
  gcgkel    → list clusters
  gcgkec X  → create cluster X
  gcgked X  → delete cluster X
  gcgkecreds X → get cluster credentials

CLOUD SQL
  gcsql     → gcloud sql
  gcsqli    → gcloud sql instances
  gcsqlil   → list instances
  gcsqlic X → create instance X
  gcsqlid X → delete instance X
  gcsqliconn X → connect to instance X

CLOUD STORAGE
  gcs       → gsutil
  gcsl      → gsutil ls
  gcscp     → gsutil cp
  gcsmv     → gsutil mv
  gcsrm     → gsutil rm
  gcsmb X   → make bucket X
  gcsrb X   → remove bucket X
  gcsync    → gsutil rsync

PROJECTS
  gcpl      → gcloud projects list
  gcpd X    → gcloud projects describe X

IAM
  gciam     → gcloud iam
  gciaml    → list service accounts
  gciamk    → service account keys

SERVICES
  gcsvc     → gcloud services
  gcsvce X  → enable service X
  gcsvcd X  → disable service X
  gcsvcs    → list services

CLOUD RUN
  gcrun     → gcloud run
  gcrund X  → deploy service X
  gcrunl    → list services
  gcrundel X→ delete service X

FZF UI HELPERS
  gcppick      → pick project → set active
  gcsshpick    → pick instance → ssh
  gcstartpick  → pick instance → start
  gcstoppick   → pick instance → stop
  gcdelpick    → pick instance → delete
  gcgkepick    → pick GKE cluster → get credentials
  gcbpick      → pick bucket → list contents
  gcsapick     → pick service account → describe
  gcrunpick    → pick Cloud Run service → describe
  gcswitch [X] → switch to project (fzf if no arg)
  gcresources  → list all resources in current project
EOF
) 
	_show_help "Google Cloud Platform" "$help_content"
}
gcp () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	local commit=$(git log --oneline --all -50 | fzf --height 40% \
    --prompt "Cherry-pick> " \
    --header "Select commit to cherry-pick" \
    --preview 'git show --color=always {1}' \
    | awk '{print $1}') 
	if [[ -n "$commit" ]]
	then
		git cherry-pick "$commit"
	else
		echo "No commit selected"
	fi
}
gcppick () {
	local project
	project=$(gcloud projects list --format="value(projectId)" \
    | fzf --height 40% --prompt "Set Project> " \
        --preview "gcloud projects describe {}")  || return
	gcloud config set project "$project"
	echo "Active project: $project"
}
gcresources () {
	echo "=== Compute Instances ==="
	gcloud compute instances list
	echo "\n=== GKE Clusters ==="
	gcloud container clusters list
	echo "\n=== Cloud SQL Instances ==="
	gcloud sql instances list
	echo "\n=== Cloud Run Services ==="
	gcloud run services list
	echo "\n=== Storage Buckets ==="
	gsutil ls
}
gcrunpick () {
	local service
	service=$(gcloud run services list --format="value(metadata.name,metadata.namespace)" \
    | fzf --height 40% --prompt "Cloud Run Service> " \
        --preview "gcloud run services describe {1} --region {2}")  || return
	local svc_name=$(echo "$service" | awk '{print $1}') 
	local svc_region=$(echo "$service" | awk '{print $2}') 
	gcloud run services describe "$svc_name" --region="$svc_region"
}
gcsapick () {
	local sa
	sa=$(gcloud iam service-accounts list --format="value(email)" \
    | fzf --height 40% --prompt "Service Account> " \
        --preview "gcloud iam service-accounts describe {}")  || return
	gcloud iam service-accounts describe "$sa"
}
gcsshpick () {
	local instance
	instance=$(gcloud compute instances list --format="value(name,zone)" \
    | fzf --height 40% --prompt "SSH to Instance> " \
        --preview "gcloud compute instances describe {1} --zone {2}")  || return
	local inst_name=$(echo "$instance" | awk '{print $1}') 
	local inst_zone=$(echo "$instance" | awk '{print $2}') 
	gcloud compute ssh "$inst_name" --zone="$inst_zone"
}
gcstartpick () {
	local instance
	instance=$(gcloud compute instances list --format="value(name,zone)" --filter="status:TERMINATED" \
    | fzf --height 40% --prompt "Start Instance> ")  || return
	local inst_name=$(echo "$instance" | awk '{print $1}') 
	local inst_zone=$(echo "$instance" | awk '{print $2}') 
	gcloud compute instances start "$inst_name" --zone="$inst_zone"
}
gcstoppick () {
	local instance
	instance=$(gcloud compute instances list --format="value(name,zone)" --filter="status:RUNNING" \
    | fzf --height 40% --prompt "Stop Instance> ")  || return
	local inst_name=$(echo "$instance" | awk '{print $1}') 
	local inst_zone=$(echo "$instance" | awk '{print $2}') 
	gcloud compute instances stop "$inst_name" --zone="$inst_zone"
}
gcswitch () {
	local project="${1}" 
	if [[ -z "$project" ]]
	then
		gcppick
		return
	fi
	gcloud config set project "$project"
}
gencert () {
	local domain="${1}" 
	local days="${2:-365}" 
	if [[ -z "$domain" ]]
	then
		echo "Usage: gencert <domain> [days]"
		return 1
	fi
	openssl req -new -x509 -days "$days" -nodes -out "${domain}.crt" -keyout "${domain}.key" -subj "/CN=${domain}"
	echo "Generated:"
	echo "  Certificate: ${domain}.crt"
	echo "  Private Key: ${domain}.key"
}
getColorCode () {
	eval "$__p9k_intro"
	if (( ARGC == 1 ))
	then
		case $1 in
			(foreground) local k
				for k in "${(k@)__p9k_colors}"
				do
					local v=${__p9k_colors[$k]} 
					print -rP -- "%F{$v}$v - $k%f"
				done
				return 0 ;;
			(background) local k
				for k in "${(k@)__p9k_colors}"
				do
					local v=${__p9k_colors[$k]} 
					print -rP -- "%K{$v}$v - $k%k"
				done
				return 0 ;;
		esac
	fi
	echo "Usage: getColorCode background|foreground" >&2
	return 1
}
get_icon_names () {
	eval "$__p9k_intro"
	_p9k_init_icons
	local key
	for key in ${(@kon)icons}
	do
		echo -n - "POWERLEVEL9K_$key: "
		print -nP "%K{red} %k"
		if [[ $1 == original ]]
		then
			echo -n - $icons[$key]
		else
			print_icon $key
		fi
		print -P "%K{red} %k"
	done
}
gfe () {
	local file
	file=$(git ls-files \
    | fzf --height 40% --preview "bat --style=numbers --color=always {}")  || return
	$EDITOR "$file"
}
gfix () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	local commit=$(git log --oneline -20 | fzf --height 40% \
    --prompt "Fixup to> " \
    --header "Select commit to fixup" \
    --preview 'git show --color=always {1}' \
    | awk '{print $1}') 
	if [[ -n "$commit" ]]
	then
		git commit --fixup "$commit"
		echo ""
		echo "Created fixup commit for: $commit"
		echo "Run 'git rebase -i --autosquash $commit~1' to squash"
	else
		echo "No commit selected"
	fi
}
ggpick () {
	local gist
	gist=$(gh gist list | fzf --height 40% --prompt "View Gist> " \
      --preview "gh gist view {1}")  || return
	local gist_id=$(echo "$gist" | awk '{print $1}') 
	gh gist view "$gist_id"
}
ghhelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE COMMANDS
  g         → gh
  grepo     → gh repo
  gpr       → gh pr
  gis       → gh issue
  grel      → gh release
  ggist     → gh gist

REPOSITORY
  grv       → gh repo view
  grvo      → gh repo view --web
  grc X     → gh repo clone X
  grcr      → gh repo create
  grf       → gh repo fork
  grlist    → gh repo list

PULL REQUESTS
  gprl      → gh pr list
  gprv X    → gh pr view X
  gprvo X   → gh pr view X --web
  gprc      → gh pr create
  gprck X   → gh pr checkout X
  gprm X    → gh pr merge X
  gprr X    → gh pr review X
  gprs      → gh pr status

ISSUES
  gisl      → gh issue list
  gisv X    → gh issue view X
  gisvo X   → gh issue view X --web
  gisc      → gh issue create
  gise X    → gh issue edit X
  giscl X   → gh issue close X

RELEASES
  grelist   → gh release list
  grec X    → gh release create X
  grev X    → gh release view X

WORKFLOWS & RUNS
  gwl       → gh workflow list
  gwr X     → gh workflow run X
  gwv X     → gh workflow view X
  grun      → gh run list
  grunv X   → gh run view X
  grunw X   → gh run watch X

GISTS
  ggl       → gh gist list
  ggc       → gh gist create
  ggv X     → gh gist view X

FZF UI HELPERS
  grcpick      → pick repo → clone
  grvpick      → pick repo → view in browser
  gprpick      → pick PR → checkout
  gprviewpick  → pick PR → view in browser
  gprmpick     → pick PR → merge (with strategy choice)
  gispick      → pick issue → view
  gisviewpick  → pick issue → view in browser
  gwrpick      → pick workflow → run
  grunpick     → pick run → view
  ggpick       → pick gist → view
  gprquick X   → quick PR create with title X
  gisquick X   → quick issue create with title X
EOF
) 
	_show_help "GitHub CLI" "$help_content"
}
ghistory () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		echo "Usage: ghistory <file>"
		return 1
	fi
	git log --oneline -- "$file" | fzf --height 70% --prompt "File History> " --preview "git show --color=always {1} -- $file"
}
gispick () {
	local issue
	issue=$(gh issue list | fzf --height 40% --prompt "View Issue> " \
      --preview "gh issue view {1}")  || return
	local issue_number=$(echo "$issue" | awk '{print $1}') 
	gh issue view "$issue_number"
}
gisquick () {
	local title="${1}" 
	if [[ -z "$title" ]]
	then
		echo "Usage: gisquick <issue-title>"
		return 1
	fi
	gh issue create --title "$title"
}
gisviewpick () {
	local issue
	issue=$(gh issue list | fzf --height 40% --prompt "View Issue> " \
      --preview "gh issue view {1}")  || return
	local issue_number=$(echo "$issue" | awk '{print $1}') 
	gh issue view "$issue_number" --web
}
glo () {
	git log --oneline --decorate | fzf --height 70% --ansi --preview "git show --color=always {1}"
}
gobuild-multi () {
	local name="${1:-app}" 
	echo "Building for linux/amd64..."
	GOOS=linux GOARCH=amd64 go build -o "${name}-linux-amd64"
	echo "Building for darwin/amd64..."
	GOOS=darwin GOARCH=amd64 go build -o "${name}-darwin-amd64"
	echo "Building for darwin/arm64..."
	GOOS=darwin GOARCH=arm64 go build -o "${name}-darwin-arm64"
	echo "Building for windows/amd64..."
	GOOS=windows GOARCH=amd64 go build -o "${name}-windows-amd64.exe"
	echo "Done! Built 4 binaries."
}
gocheck () {
	echo "Running go fmt..."
	go fmt ./... || return
	echo "Running go vet..."
	go vet ./... || return
	echo "Running go test..."
	go test ./...
}
gohelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE COMMANDS
  gob       → go build
  gobr      → go build -race
  gor       → go run
  gorr      → go run -race
  got       → go test
  gotv      → go test -v
  gotr      → go test -race
  gotc      → go test -cover
  gotb      → go test -bench=.

MODULE MANAGEMENT
  gom       → go mod
  gomi X    → go mod init X
  gomt      → go mod tidy
  gomv      → go mod verify
  gomd      → go mod download
  gomg      → go mod graph

GO GET/INSTALL
  gog X     → go get X
  gogu X    → go get -u X
  goi X     → go install X

FORMATTING & TOOLS
  gof       → go fmt
  gofa      → go fmt ./...
  govet     → go vet
  goveta    → go vet ./...

BUILD & TEST ALL
  goba      → go build ./...
  gota      → go test ./...

CLEAN
  goclean   → go clean
  gocleani  → go clean -i
  gocleanc  → go clean -cache

GO WORKSPACE
  gow       → go work
  gowi      → go work init
  gowu X    → go work use X

FZF UI HELPERS
  gorpick      → pick .go file → run
  gotpick      → pick test file → run tests
  gotpkgpick   → pick package → test
  goipick      → pick installed binary → run
  goquick X    → init module + create main.go
  gotcov       → run tests with coverage → open in browser
  gocheck      → fmt + vet + test in sequence
  gobuild-multi X → build for multiple platforms
EOF
) 
	_show_help "Go Development" "$help_content"
}
goipick () {
	local bin_dir="${GOPATH:-$HOME/go}/bin" 
	if [[ ! -d "$bin_dir" ]]
	then
		echo "No Go bin directory found"
		return 1
	fi
	local bin
	bin=$(ls "$bin_dir" 2>/dev/null \
    | fzf --height 40% --prompt "Go Binary> ")  || return
	"$bin_dir/$bin"
}
goquick () {
	local module="${1}" 
	if [[ -z "$module" ]]
	then
		echo "Usage: goquick <module-name>"
		echo "Example: goquick github.com/user/project"
		return 1
	fi
	go mod init "$module"
	batcat > main.go <<'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
EOF
	echo "Initialized Go module: $module"
	echo "Created main.go"
}
gorpick () {
	local file
	file=$(find . -name "*.go" -not -path "*/vendor/*" -not -path "*/.git/*" \
    | fzf --height 40% --prompt "Go File> " \
        --preview "bat --color=always {}")  || return
	go run "$file"
}
gotcov () {
	go test -coverprofile=coverage.out ./... && go tool cover -html=coverage.out
}
gotpick () {
	local file
	file=$(find . -name "*_test.go" -not -path "*/vendor/*" \
    | fzf --height 40% --prompt "Test File> " \
        --preview "bat --color=always {}")  || return
	go test -v "$(dirname "$file")"
}
gotpkgpick () {
	local pkg
	pkg=$(go list ./... 2>/dev/null \
    | fzf --height 40% --prompt "Package> ")  || return
	go test -v "$pkg"
}
gpgdecfile () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		echo "Usage: gpgdecfile <encrypted-file>"
		return 1
	fi
	gpg --decrypt "$file"
}
gpgencfile () {
	local file="${1}" 
	local recipient="${2}" 
	if [[ -z "$file" || -z "$recipient" ]]
	then
		echo "Usage: gpgencfile <file> <recipient-email>"
		return 1
	fi
	gpg --encrypt --armor --recipient "$recipient" "$file"
	echo "Encrypted: ${file}.asc"
}
gpgexppick () {
	local key
	key=$(gpg --list-keys --with-colons | grep '^uid' | cut -d: -f10 \
    | fzf --height 40% --prompt "Export GPG Key> ")  || return
	local keyid=$(gpg --list-keys "$key" | grep 'pub' | awk '{print $2}' | cut -d'/' -f2) 
	local output="${keyid}.asc" 
	gpg --export --armor "$keyid" > "$output"
	echo "Exported to: $output"
}
gpggenkey () {
	local name="${1}" 
	local email="${2}" 
	if [[ -z "$name" || -z "$email" ]]
	then
		echo "Usage: gpggenkey <name> <email>"
		return 1
	fi
	gpg --batch --generate-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $name
Name-Email: $email
Expire-Date: 0
%ask-passphrase
%commit
EOF
}
gpgkeypick () {
	local key
	key=$(gpg --list-keys --with-colons | grep '^uid' | cut -d: -f10 \
    | fzf --height 40% --prompt "GPG Key> " \
        --preview "gpg --list-keys '{}'")  || return
	gpg --list-keys "$key"
}
gpgsignfile () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		echo "Usage: gpgsignfile <file>"
		return 1
	fi
	gpg --sign --armor "$file"
	echo "Signed: ${file}.asc"
}
gprmpick () {
	local pr
	pr=$(gh pr list | fzf --height 40% --prompt "Merge PR> " \
      --preview "gh pr view {1}")  || return
	local pr_number=$(echo "$pr" | awk '{print $1}') 
	echo "Merge PR #$pr_number?"
	read "?Choose merge strategy (m=merge, s=squash, r=rebase, c=cancel): " strategy
	case "$strategy" in
		(m) gh pr merge "$pr_number" --merge ;;
		(s) gh pr merge "$pr_number" --squash ;;
		(r) gh pr merge "$pr_number" --rebase ;;
		(*) echo "Cancelled" ;;
	esac
}
gprpick () {
	local pr
	pr=$(gh pr list | fzf --height 40% --prompt "Checkout PR> " \
      --preview "gh pr view {1}")  || return
	local pr_number=$(echo "$pr" | awk '{print $1}') 
	gh pr checkout "$pr_number"
}
gprq () {
	local branch=$(git branch --show-current) 
	local base=$(git symbolic-ref refs/remotes/origin/HEAD \
    | sed 's@^refs/remotes/origin/@@') 
	gh pr create --title "$branch" --body "" --base "$base" --head "$branch"
}
gprquick () {
	local title="${1}" 
	if [[ -z "$title" ]]
	then
		echo "Usage: gprquick <pr-title>"
		return 1
	fi
	gh pr create --title "$title" --fill
}
gprviewpick () {
	local pr
	pr=$(gh pr list | fzf --height 40% --prompt "View PR> " \
      --preview "gh pr view {1}")  || return
	local pr_number=$(echo "$pr" | awk '{print $1}') 
	gh pr view "$pr_number" --web
}
grcpick () {
	local repo
	repo=$(gh repo list --limit 100 | fzf --height 40% --prompt "Clone Repo> " \
      --preview "gh repo view {1}")  || return
	local repo_name=$(echo "$repo" | awk '{print $1}') 
	gh repo clone "$repo_name"
}
grebase () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	local commit=$(git log --oneline -30 | fzf --height 40% \
    --prompt "Rebase from> " \
    --header "Select commit to rebase from" \
    --preview 'git show --color=always {1}' \
    | awk '{print $1}') 
	if [[ -n "$commit" ]]
	then
		git rebase -i "$commit~1"
	else
		echo "No commit selected"
	fi
}
greppick () {
	local pattern="${1}" 
	local path="${2:-.}" 
	if [[ -z "$pattern" ]]
	then
		echo "Usage: greppick <pattern> [path]"
		return 1
	fi
	grep -r -n "$pattern" "$path" 2> /dev/null | fzf --height 40% --prompt "Match> " --delimiter=: --preview 'bat --color=always --highlight-line {2} {1}' | awk -F: '{print $1":"$2}'
}
grunpick () {
	local run
	run=$(gh run list --limit 50 | fzf --height 40% --prompt "View Run> " \
      --preview "gh run view {7}")  || return
	local run_id=$(echo "$run" | awk '{print $7}') 
	gh run view "$run_id"
}
grvpick () {
	local repo
	repo=$(gh repo list --limit 100 | fzf --height 40% --prompt "View Repo> " \
      --preview "gh repo view {1}")  || return
	local repo_name=$(echo "$repo" | awk '{print $1}') 
	gh repo view "$repo_name" --web
}
gshelp () {
	local help_content
	help_content=$(cat <<'EOF'
STATUS / DIFF
  gs      → git status -sb
  gd      → git diff
  gds     → git diff --staged

ADD / COMMIT / AMEND
  ga      → git add
  gc      → git commit
  gca     → git commit --amend --no-edit

LOG / HISTORY
  gl      → git log --oneline --graph --decorate
  glo     → fzf commit browser

BRANCH OPS
  gb      → git branch
  gco     → git checkout
  gnb     → git checkout -b <branch>
  g-      → git switch -

PULL / PUSH / FETCH
  gp      → git pull --ff-only
  gP      → git push
  gf      → git fetch --all --prune

CLEANUP / RESET
  gcln    → git clean -xdf -i (interactive)
  gun     → undo last commit (keep changes)

WORKTREES (Enhanced with FZF!)
  gwt X       → create worktree for existing branch X
  gwtnew X    → create new branch + worktree
  gwtpick     → create worktree (fzf branch picker)
  gwtls       → list all worktrees with details
  gwtcd       → cd to worktree (fzf picker)
  gwtrm       → remove worktree (fzf picker, asks about branch deletion)
  gwtp        → git worktree prune

FILE LISTS
  gcf     → list conflicted files
  gsf     → short status with branch

STASH
  gss     → git stash save
  gsl     → git stash list
  gsa     → git stash apply
  gsp     → git stash pop
  gst     → fzf stash browser

FZF UI HELPERS
  gbr     → fzf branch switcher
  gfe     → fzf file picker (opens in \$EDITOR)

GITHUB PR
  gprq    → create PR quick (current branch → origin default branch)

ENHANCED WORKFLOW
  gac         → add files interactively (fzf) + commit
  gfix        → create fixup commit (fzf commit picker)
  gundo [N]   → undo last N commits (keep changes staged)
  gundosoft [N] → undo last N commits (keep changes unstaged)
  gsyncfork [B] → sync fork with upstream (branch B, default: main)
  grebase     → interactive rebase (fzf commit picker)
  ghistory X  → show file history with fzf
  gamend      → quick amend (add changes to last commit)
  gcp         → cherry-pick commit (fzf picker)
  gshow       → show commit diff (fzf picker)
  gstm X      → stash with message X
  gunstage    → unstage files (fzf picker)
EOF
) 
	_show_help "Git Shortcuts" "$help_content"
}
gshow () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	local commit=$(git log --oneline -50 | fzf --height 70% \
    --prompt "Show commit> " \
    --preview 'git show --color=always {1}' \
    | awk '{print $1}') 
	if [[ -n "$commit" ]]
	then
		git show "$commit"
	fi
}
gst () {
	local stash
	stash=$(git stash list \
    | fzf --height 40% --preview "git stash show -p {1}")  || return
	git stash apply "$(echo "$stash" | cut -d: -f1)"
}
gstm () {
	local msg="${1}" 
	if [[ -z "$msg" ]]
	then
		echo "Usage: gstm <message>"
		return 1
	fi
	git stash push -m "$msg"
}
gsyncfork () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	if ! git remote | grep -q "^upstream$"
	then
		echo "No 'upstream' remote found"
		echo ""
		echo "Add upstream remote first:"
		echo "  git remote add upstream <upstream-url>"
		return 1
	fi
	local branch="${1:-main}" 
	echo "Syncing fork with upstream/$branch..."
	git fetch upstream
	git checkout "$branch"
	git merge "upstream/$branch"
	echo ""
	echo -n "Push to origin? (y/N): "
	read answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		git push origin "$branch"
	fi
}
gundo () {
	local n="${1:-1}" 
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	echo "Undoing last $n commit(s) (keeping changes staged)"
	git reset --soft HEAD~$n
	echo ""
	git status -sb
}
gundosoft () {
	local n="${1:-1}" 
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	echo "Undoing last $n commit(s) (keeping changes unstaged)"
	git reset --mixed HEAD~$n
	echo ""
	git status -sb
}
gunstage () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	local files=$(git diff --cached --name-only | fzf -m --height 40% \
    --prompt "Unstage> " \
    --header "Select files to unstage" \
    --preview 'git diff --cached --color=always {}') 
	if [[ -n "$files" ]]
	then
		echo "$files" | xargs git restore --staged
		echo "Unstaged files:"
		echo "$files"
	else
		echo "No files selected"
	fi
}
gwrpick () {
	local workflow
	workflow=$(gh workflow list | fzf --height 40% --prompt "Run Workflow> ")  || return
	local workflow_name=$(echo "$workflow" | awk '{print $1}') 
	gh workflow run "$workflow_name"
}
gwt () {
	local branch="$1" 
	[[ -z "$branch" ]] && {
		echo "Usage: gwt <branch>"
		return 1
	}
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	git show-ref --quiet "refs/heads/$branch" || {
		echo "Branch '$branch' does not exist."
		return 1
	}
	local repo_root=$(git rev-parse --show-toplevel) 
	local dir="$(dirname "$repo_root")/$branch" 
	[[ -d "$dir" ]] && {
		echo "Directory '$dir' already exists."
		return 1
	}
	git worktree prune > /dev/null 2>&1
	git worktree add "$dir" "$branch"
	echo ""
	echo "✓ Worktree created at: $dir"
}
gwtcd () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	local worktree=$(git worktree list | fzf --height 40% \
        --prompt "Change to worktree> " \
        --header "Select worktree to cd into" \
        --preview 'echo {}' | awk '{print $1}') 
	if [[ -n "$worktree" ]]
	then
		cd "$worktree"
		echo "Changed to: $worktree"
		echo ""
		git status -sb
	else
		echo "No worktree selected"
	fi
}
gwtls () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	echo "=== Git Worktrees ==="
	echo ""
	git worktree list
	echo ""
	local count=$(git worktree list | wc -l) 
	echo "Total worktrees: $count"
}
gwtnew () {
	local branch="$1" 
	[[ -z "$branch" ]] && {
		echo "Usage: gwtnew <new-branch>"
		return 1
	}
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	if git show-ref --quiet "refs/heads/$branch"
	then
		echo "Branch '$branch' already exists locally. Use 'gwt $branch' instead."
		return 1
	fi
	echo "Fetching remote branches..."
	git fetch --all --prune
	local repo_root=$(git rev-parse --show-toplevel) 
	local dir="$(dirname "$repo_root")/$branch" 
	[[ -d "$dir" ]] && {
		echo "Directory '$dir' already exists."
		return 1
	}
	git worktree prune > /dev/null 2>&1
	if git show-ref --quiet "refs/remotes/origin/$branch"
	then
		git worktree add "$dir" "$branch"
		echo ""
		echo "✓ Worktree created at: $dir (tracking origin/$branch)"
	else
		git worktree add -b "$branch" "$dir"
		echo ""
		echo "✓ New branch '$branch' created with worktree at: $dir"
	fi
}
gwtpick () {
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	local branch=$(git branch --all --color=always | sed 's/^..//' \
        | grep -v "HEAD" \
        | fzf --height 40% --ansi --prompt "Create worktree for> " \
            --header "Select branch to create worktree" \
            --preview "git log --oneline --graph --decorate --color=always '{}'" \
        | sed 's#remotes/[^/]*/##') 
	if [[ -n "$branch" ]]
	then
		branch=$(echo "$branch" | xargs) 
		local repo_root=$(git rev-parse --show-toplevel) 
		local dir="$(dirname "$repo_root")/$branch" 
		if [[ -d "$dir" ]]
		then
			echo "Directory '$dir' already exists."
			return 1
		fi
		git worktree prune > /dev/null 2>&1
		git worktree add "$dir" "$branch"
		echo ""
		echo "✓ Worktree created at: $dir"
		echo ""
		echo -n "Change to new worktree? (y/N): "
		read answer
		if [[ "$answer" == "y" || "$answer" == "Y" ]]
		then
			cd "$dir"
			git status -sb
		fi
	else
		echo "No branch selected"
	fi
}
gwtrm () {
	if ! command -v git &> /dev/null
	then
		echo "Error: git is not installed or not in PATH"
		echo "Please install git to use this command"
		return 1
	fi
	if ! git rev-parse --git-dir > /dev/null 2>&1
	then
		echo "Not a git repository"
		return 1
	fi
	local worktree_count=$(git worktree list | wc -l) 
	if [[ $worktree_count -eq 0 ]]
	then
		echo "No worktrees found"
		return 0
	fi
	local worktree=$(git worktree list | fzf --height 40% \
        --prompt "Remove worktree> " \
        --header "Select worktree to remove" \
        --preview 'echo {}') 
	if [[ -n "$worktree" ]]
	then
		local parts=("${(@s: :)worktree}") 
		local path="${parts[1]}" 
		local branch="${parts[3]}" 
		local main_worktree=$(git worktree list | head -n 1 | awk '{print $1}') 
		if [[ "$path" == "$main_worktree" || "$path" == "$(git rev-parse --show-toplevel)" ]]
		then
			echo ""
			echo "Cannot remove the main or current worktree: $path"
			echo "Please switch to another worktree first."
			return 1
		fi
		branch="${branch#\[}" 
		branch="${branch%\]}" 
		[[ "$branch" == "("* ]] && branch="" 
		echo ""
		echo "Path: $path"
		echo "Branch: ${branch:-(detached HEAD)}"
		echo ""
		echo -n "Remove this worktree? (y/N): "
		read answer
		if [[ "$answer" == "y" || "$answer" == "Y" ]]
		then
			if ! command -v git &> /dev/null
			then
				echo "Error: git is not available"
				return 1
			fi
			git worktree remove "$path"
			echo "✓ Worktree removed: $path"
			if [[ -n "$branch" ]]
			then
				echo ""
				echo -n "Delete branch '$branch' as well? (y/N): "
				read delete_branch
				if [[ "$delete_branch" == "y" || "$delete_branch" == "Y" ]]
				then
					if command -v git &> /dev/null
					then
						git branch -D "$branch"
						echo "✓ Branch deleted: $branch"
					else
						echo "Error: git not available for branch deletion"
					fi
				fi
			fi
		else
			echo "Cancelled"
		fi
	else
		echo "No worktree selected"
	fi
}
hashfile () {
	local file="${1}" 
	local algo="${2:-sha256}" 
	if [[ -z "$file" ]]
	then
		echo "Usage: hashfile <file> [algorithm]"
		echo "Algorithms: md5, sha1, sha256 (default), sha512"
		return 1
	fi
	case "$algo" in
		(md5) md5sum "$file" ;;
		(sha1) sha1sum "$file" ;;
		(sha256) sha256sum "$file" ;;
		(sha512) sha512sum "$file" ;;
		(*) echo "Unknown algorithm: $algo"
			return 1 ;;
	esac
}
hchart () {
	local chart
	chart=$(helm search repo | fzf --height 40%)  || return
	chart=$(echo "$chart" | awk '{print $1}') 
	echo "Installing chart: $chart"
	helm install "$chart" "$chart"
}
helpbrowse () {
	local helpers=("gshelp - Git shortcuts" "ghhelp - GitHub CLI shortcuts" "syshelp - System monitoring" "sechelp - Security & crypto tools" "apihelp - API testing" "nethelp - Network tools" "texthelp - Text processing" "makehelp - Build systems" "vaulthelp - HashiCorp Vault" "consulhelp - HashiCorp Consul" "jenkinshelp - Jenkins CI/CD" "anshelp - Ansible" "gchelp - Google Cloud" "devhelp - Development workflows" "perfhelp - Performance monitoring" "pyhelp - Python development" "nodehelp - Node.js & npm" "gohelp - Go development" "cargohelp - Cargo & Rust" "awshelp - AWS CLI" "tfhelp - Terraform" "dshelp - Docker" "kbhelp - Kubernetes" "hmhelp - Helm" "vghelp - Vagrant" "sysdhelp - systemd" "tmhelp - Tmux" "dbhelp - Database tools") 
	local selection=$(printf '%s\n' "${helpers[@]}" \
    | fzf --height 40% --prompt "Help> " \
          --preview "echo {} | awk '{print \$1}' | xargs -I {} sh -c '{}'") 
	if [[ -n "$selection" ]]
	then
		local cmd=$(echo "$selection" | awk '{print $1}') 
		eval "$cmd"
	fi
}
helpgrep () {
	local pattern="${1}" 
	if [[ -z "$pattern" ]]
	then
		echo "Usage: helpgrep <pattern>"
		echo "Example: helpgrep docker"
		return 1
	fi
	local helpers=(gshelp ghhelp syshelp sechelp apihelp nethelp texthelp makehelp vaulthelp consulhelp jenkinshelp anshelp gchelp devhelp perfhelp pyhelp nodehelp gohelp cargohelp awshelp tfhelp dshelp kbhelp hmhelp vghelp sysdhelp tmhelp dbhelp) 
	local found=0 
	for helper in $helpers
	do
		if command -v $helper > /dev/null 2>&1
		then
			local output=$($helper 2>/dev/null | grep -i "$pattern") 
			if [[ -n "$output" ]]
			then
				echo "=== Found in: $helper ==="
				echo "$output" | grep -i --color=always "$pattern"
				echo ""
				found=1 
			fi
		fi
	done
	if [[ $found -eq 0 ]]
	then
		echo "No matches found for: $pattern"
		echo "Try 'allhelp' to see available help commands"
	fi
}
helplist () {
	local helpers=(gshelp ghhelp syshelp sechelp apihelp nethelp texthelp makehelp vaulthelp consulhelp jenkinshelp anshelp gchelp devhelp perfhelp pyhelp nodehelp gohelp cargohelp awshelp tfhelp dshelp kbhelp hmhelp vghelp sysdhelp tmhelp dbhelp) 
	echo "=== All Available Commands ==="
	echo ""
	for helper in $helpers
	do
		if command -v $helper > /dev/null 2>&1
		then
			echo "--- From $helper ---"
			$helper 2> /dev/null | grep -E '^\s+\w+' | sed 's/^/  /'
			echo ""
		fi
	done
}
hh () {
	local category="${1}" 
	if [[ -z "$category" ]]
	then
		allhelp
		return
	fi
	case "$category" in
		(git) gshelp ;;
		(github | gh) ghhelp ;;
		(sys | system) syshelp ;;
		(sec | security) sechelp ;;
		(api) apihelp ;;
		(net | network) nethelp ;;
		(text) texthelp ;;
		(make | build) makehelp ;;
		(vault) vaulthelp ;;
		(consul) consulhelp ;;
		(jenkins | ci) jenkinshelp ;;
		(ansible) anshelp ;;
		(gcloud | gc) gchelp ;;
		(dev) devhelp ;;
		(perf) perfhelp ;;
		(python | py) pyhelp ;;
		(node | nodejs | npm) nodehelp ;;
		(go | golang) gohelp ;;
		(cargo | rust) cargohelp ;;
		(aws) awshelp ;;
		(terraform | tf) tfhelp ;;
		(docker) dshelp ;;
		(kubernetes | k8s | kubectl) kbhelp ;;
		(helm) hmhelp ;;
		(vagrant) vghelp ;;
		(systemd | sysd) sysdhelp ;;
		(tmux | tm) tmhelp ;;
		(database | db) dbhelp ;;
		(*) echo "Unknown category: $category"
			echo "Try: hh git, hh docker, hh python, hh k8s, etc."
			echo "Or use 'allhelp' to see all categories" ;;
	esac
}
hmhelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE
  h         → helm
  hl        → helm list
  hla       → helm list --all-namespaces
  hls       → helm search repo

INSTALL / UPGRADE / DELETE
  hli X     → helm install X
  hlu X     → helm upgrade X
  hld X     → helm delete X
  hlr X     → helm rollback X
  hhist X   → helm history X

REPOS
  hr        → helm repo
  hra X Y   → helm repo add X Y
  hrup      → helm repo update

TEMPLATE / LINT
  htpl X    → helm template X
 htv X Y    → helm template --values Y X
  hlt X     → helm lint X

FZF UI HELPERS
  hrpick    → pick release → helm status
  hchart    → pick chart → install
  hu        → pick release → upgrade
  hud       → pick release → delete
EOF
) 
	_show_help "Helm Package Manager" "$help_content"
}
hrpick () {
	local rel ns
	read rel ns <<< "$(helm list --all-namespaces -o json \
    | jq -r '.[] | "\(.name) \(.namespace)"' \
    | fzf --height 40% --prompt "Helm Release> " --preview "helm status {1} -n {2}")"
	[[ -n "$rel" && -n "$ns" ]] && helm status "$rel" -n "$ns"
}
httpstatus () {
	local url="${1}" 
	if [[ -z "$url" ]]
	then
		echo "Usage: httpstatus <url>"
		return 1
	fi
	curl -o /dev/null -s -w "HTTP Status: %{http_code}\nTime: %{time_total}s\n" "$url"
}
hu () {
	local rel ns chart
	read rel ns <<< "$(helm list --all-namespaces -o json \
    | jq -r '.[] | "\(.name) \(.namespace)"' \
    | fzf --height 40% --prompt "Helm Release to Upgrade> ")"
	[[ -z "$rel" ]] && return
	chart=$(fzf --prompt "Chart directory> " --height 40%) 
	helm upgrade "$rel" "$chart" -n "$ns"
}
hud () {
	local rel ns
	read rel ns <<< "$(helm list --all-namespaces -o json \
    | jq -r '.[] | "\(.name) \(.namespace)"' \
    | fzf --height 40%)"
	[[ -n "$rel" && -n "$ns" ]] && helm delete "$rel" -n "$ns"
}
ifpick () {
	local iface
	iface=$(ip -br addr | awk '{print $1}' \
    | fzf --height 40% --prompt "Network Interface> " \
        --preview "ip addr show {}")  || return
	ip addr show "$iface"
}
instant_prompt__p9k_internal_nothing () {
	prompt__p9k_internal_nothing
}
instant_prompt_chezmoi_shell () {
	_p9k_prompt_segment prompt_chezmoi_shell blue $_p9k_color1 CHEZMOI_ICON 1 '$CHEZMOI_ICON' ''
}
instant_prompt_context () {
	if [[ $_POWERLEVEL9K_ALWAYS_SHOW_CONTEXT == 0 && -n $DEFAULT_USER && $P9K_SSH == 0 ]]
	then
		if [[ ${(%):-%n} == $DEFAULT_USER ]]
		then
			if (( ! _POWERLEVEL9K_ALWAYS_SHOW_USER ))
			then
				return
			fi
		fi
	fi
	prompt_context
}
instant_prompt_date () {
	_p9k_escape $_POWERLEVEL9K_DATE_FORMAT
	local stash='${${__p9k_instant_prompt_date::=${(%)${__p9k_instant_prompt_date_format::='$_p9k__ret'}}}+}' 
	_p9k_escape $_POWERLEVEL9K_DATE_FORMAT
	_p9k_prompt_segment prompt_date "$_p9k_color2" "$_p9k_color1" "DATE_ICON" 1 '' $stash$_p9k__ret
}
instant_prompt_dir () {
	prompt_dir
}
instant_prompt_dir_writable () {
	prompt_dir_writable
}
instant_prompt_direnv () {
	if [[ -n ${DIRENV_DIR:-} && $precmd_functions[-1] == _p9k_precmd ]]
	then
		_p9k_prompt_segment prompt_direnv $_p9k_color1 yellow DIRENV_ICON 0 '' ''
	fi
}
instant_prompt_example () {
	prompt_example
}
instant_prompt_host () {
	prompt_host
}
instant_prompt_lf () {
	_p9k_prompt_segment prompt_lf 6 $_p9k_color1 LF_ICON 1 '${LF_LEVEL:#0}' '$LF_LEVEL'
}
instant_prompt_midnight_commander () {
	_p9k_prompt_segment prompt_midnight_commander $_p9k_color1 yellow MIDNIGHT_COMMANDER_ICON 0 '$MC_TMPDIR' ''
}
instant_prompt_nix_shell () {
	_p9k_prompt_segment prompt_nix_shell 4 $_p9k_color1 NIX_SHELL_ICON 1 "$_p9k_nix_shell_cond" '${(M)IN_NIX_SHELL:#(pure|impure)}'
}
instant_prompt_nnn () {
	_p9k_prompt_segment prompt_nnn 6 $_p9k_color1 NNN_ICON 1 '${NNNLVL:#0}' '$NNNLVL'
}
instant_prompt_os_icon () {
	prompt_os_icon
}
instant_prompt_per_directory_history () {
	case $HISTORY_START_WITH_GLOBAL in
		(true) _p9k_prompt_segment prompt_per_directory_history_GLOBAL 3 $_p9k_color1 HISTORY_ICON 0 '' global ;;
		(?*) _p9k_prompt_segment prompt_per_directory_history_LOCAL 5 $_p9k_color1 HISTORY_ICON 0 '' local ;;
	esac
}
instant_prompt_prompt_char () {
	_p9k_prompt_segment prompt_prompt_char_OK_VIINS "$_p9k_color1" 76 '' 0 '' '❯'
}
instant_prompt_ranger () {
	_p9k_prompt_segment prompt_ranger $_p9k_color1 yellow RANGER_ICON 1 '$RANGER_LEVEL' '$RANGER_LEVEL'
}
instant_prompt_root_indicator () {
	prompt_root_indicator
}
instant_prompt_ssh () {
	if (( ! P9K_SSH ))
	then
		return
	fi
	prompt_ssh
}
instant_prompt_status () {
	if (( _POWERLEVEL9K_STATUS_OK ))
	then
		_p9k_prompt_segment prompt_status_OK "$_p9k_color1" green OK_ICON 0 '' ''
	fi
}
instant_prompt_time () {
	_p9k_escape $_POWERLEVEL9K_TIME_FORMAT
	local stash='${${__p9k_instant_prompt_time::=${(%)${__p9k_instant_prompt_time_format::='$_p9k__ret'}}}+}' 
	_p9k_escape $_POWERLEVEL9K_TIME_FORMAT
	_p9k_prompt_segment prompt_time "$_p9k_color2" "$_p9k_color1" "TIME_ICON" 1 '' $stash$_p9k__ret
}
instant_prompt_toolbox () {
	_p9k_prompt_segment prompt_toolbox $_p9k_color1 yellow TOOLBOX_ICON 1 '$P9K_TOOLBOX_NAME' '$P9K_TOOLBOX_NAME'
}
instant_prompt_user () {
	if [[ $_POWERLEVEL9K_ALWAYS_SHOW_USER == 0 && "${(%):-%n}" == $DEFAULT_USER ]]
	then
		return
	fi
	prompt_user
}
instant_prompt_vi_mode () {
	if [[ -n $_POWERLEVEL9K_VI_INSERT_MODE_STRING ]]
	then
		_p9k_prompt_segment prompt_vi_mode_INSERT "$_p9k_color1" blue '' 0 '' "$_POWERLEVEL9K_VI_INSERT_MODE_STRING"
	fi
}
instant_prompt_vim_shell () {
	_p9k_prompt_segment prompt_vim_shell green $_p9k_color1 VIM_ICON 0 '$VIMRUNTIME' ''
}
instant_prompt_xplr () {
	_p9k_prompt_segment prompt_xplr 6 $_p9k_color1 XPLR_ICON 0 '$XPLR_PID' ''
}
instant_prompt_yazi () {
	_p9k_prompt_segment prompt_yazi $_p9k_color1 yellow YAZI_ICON 1 '$YAZI_LEVEL' '$YAZI_LEVEL'
}
iomon () {
	if ! command -v iostat > /dev/null 2>&1
	then
		echo "iostat not installed"
		echo "Install with: sudo dnf install sysstat"
		return 1
	fi
	local interval="${1:-2}" 
	echo "Monitoring disk I/O (interval: ${interval}s, press Ctrl+C to stop)"
	iostat -x "$interval"
}
iostats () {
	iostat -xz 2 5 2> /dev/null || echo "iostat not installed. Install with: sudo dnf install sysstat"
}
jenkinshelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE OPERATIONS
  jk        → jenkins-cli
  jkh       → jenkins-cli help
  jkv       → jenkins-cli version
  jkwho     → jenkins-cli who-am-i

JOB OPERATIONS
  jkb X     → jenkins-cli build X
  jkc X     → jenkins-cli console X
  jkl       → jenkins-cli list-jobs
  jkcp X Y  → jenkins-cli copy-job X Y
  jkdel X   → jenkins-cli delete-job X
  jkget X   → jenkins-cli get-job X
  jkcr X    → jenkins-cli create-job X

BUILD OPERATIONS
  jkbh X    → jenkins-cli build-history X
  jkbs X    → jenkins-cli build-status X
  jkstop X  → jenkins-cli stop-build X

NODE OPERATIONS
  jkn       → jenkins-cli list-nodes
  jknon X   → jenkins-cli online-node X
  jknoff X  → jenkins-cli offline-node X
  jknd X    → jenkins-cli delete-node X
  jkncr X   → jenkins-cli create-node X

PLUGIN OPERATIONS
  jkp       → jenkins-cli list-plugins
  jkpi X    → jenkins-cli install-plugin X
  jkpr      → jenkins-cli restart
  jkps      → jenkins-cli safe-restart

QUEUE
  jkq       → jenkins-cli list-queue
  jkqc X    → jenkins-cli cancel-queue X

GROOVY
  jkgroovy  → jenkins-cli groovy
  jkgsh     → jenkins-cli groovysh

FZF UI HELPERS
  jkbpick       → pick job → build
  jkcpick       → pick job → view console
  jkgetpick     → pick job → view config
  jkdelpick     → pick job → delete
  jknpick       → pick node → view
  jknoffpick    → pick node → offline
  jknonpick     → pick node → online
  jkppick       → pick plugin → view info
  jkbparam X Y  → build job X with params Y
  jkwatch X [Y] → watch console for job X build Y
  jkfailed      → list failed jobs
  jkrunning     → list running jobs
  jkbwait X     → build X and wait for completion
  jkclone X Y   → clone job X to Y
  jkrunscript X → execute groovy script from file X
  jkhistory X [N] → show build history for job X (N builds)
  jkrestart     → restart Jenkins (with prompt)
EOF
) 
	_show_help "Jenkins CI/CD" "$help_content"
}
jkbparam () {
	local job="${1}" 
	shift
	local params="$@" 
	if [[ -z "$job" ]]
	then
		echo "Usage: jkbparam <job-name> [key=value ...]"
		return 1
	fi
	jenkins-cli build "$job" -p $params
}
jkbpick () {
	local job
	job=$(jenkins-cli list-jobs 2>/dev/null \
    | fzf --height 40% --prompt "Build Job> " \
        --preview "jenkins-cli get-job {}")  || return
	echo "Building job: $job"
	jenkins-cli build "$job"
}
jkbwait () {
	local job="${1}" 
	if [[ -z "$job" ]]
	then
		echo "Usage: jkbwait <job-name>"
		return 1
	fi
	echo "Building $job and waiting for completion..."
	jenkins-cli build "$job" -s -v
}
jkclone () {
	local source="${1}" 
	local target="${2}" 
	if [[ -z "$source" || -z "$target" ]]
	then
		echo "Usage: jkclone <source-job> <target-job>"
		return 1
	fi
	jenkins-cli copy-job "$source" "$target"
	echo "Cloned $source to $target"
}
jkcpick () {
	local job
	job=$(jenkins-cli list-jobs 2>/dev/null \
    | fzf --height 40% --prompt "Console Output> ")  || return
	jenkins-cli console "$job"
}
jkdelpick () {
	local job
	job=$(jenkins-cli list-jobs 2>/dev/null \
    | fzf --height 40% --prompt "Delete Job> ")  || return
	echo "Delete job: $job?"
	read "?Confirm (y/N): " answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		jenkins-cli delete-job "$job"
	else
		echo "Cancelled"
	fi
}
jkfailed () {
	echo "=== Failed Jobs ==="
	jenkins-cli list-jobs 2> /dev/null | while read job
	do
		local status=$(jenkins-cli build-status "$job" 2>/dev/null | tail -1) 
		if [[ "$status" == *"FAILURE"* ]]
		then
			echo "$job - FAILED"
		fi
	done
}
jkgetpick () {
	local job
	job=$(jenkins-cli list-jobs 2>/dev/null \
    | fzf --height 40% --prompt "View Job Config> " \
        --preview "jenkins-cli get-job {}")  || return
	jenkins-cli get-job "$job"
}
jkhistory () {
	local job="${1}" 
	local count="${2:-10}" 
	if [[ -z "$job" ]]
	then
		echo "Usage: jkhistory <job-name> [count]"
		return 1
	fi
	jenkins-cli build-history "$job" | head -n "$count"
}
jknoffpick () {
	local node
	node=$(jenkins-cli list-nodes 2>/dev/null \
    | fzf --height 40% --prompt "Offline Node> ")  || return
	jenkins-cli offline-node "$node"
	echo "Node $node is now offline"
}
jknonpick () {
	local node
	node=$(jenkins-cli list-nodes 2>/dev/null \
    | fzf --height 40% --prompt "Online Node> ")  || return
	jenkins-cli online-node "$node"
	echo "Node $node is now online"
}
jknpick () {
	local node
	node=$(jenkins-cli list-nodes 2>/dev/null \
    | fzf --height 40% --prompt "Node> ")  || return
	echo "Node: $node"
	jenkins-cli get-node "$node" 2> /dev/null || echo "Details for: $node"
}
jkppick () {
	local plugin
	plugin=$(jenkins-cli list-plugins 2>/dev/null | awk '{print $1}' \
    | fzf --height 40% --prompt "Plugin> ")  || return
	jenkins-cli list-plugins | grep "$plugin"
}
jkrestart () {
	echo "Restarting Jenkins..."
	read "?Use safe restart? (y/N): " answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		jenkins-cli safe-restart
	else
		jenkins-cli restart
	fi
}
jkrunning () {
	echo "=== Running Jobs ==="
	jenkins-cli list-queue 2> /dev/null
}
jkrunscript () {
	local script="${1}" 
	if [[ -z "$script" || ! -f "$script" ]]
	then
		echo "Usage: jkrunscript <groovy-script-file>"
		return 1
	fi
	jenkins-cli groovy = < "$script"
}
jkwatch () {
	local job="${1}" 
	local build="${2:-lastBuild}" 
	if [[ -z "$job" ]]
	then
		echo "Usage: jkwatch <job-name> [build-number]"
		return 1
	fi
	echo "Watching console output for $job #$build..."
	watch -n 2 "jenkins-cli console $job $build"
}
jqexplore () {
	local file="${1}" 
	if [[ -z "$file" || ! -f "$file" ]]
	then
		echo "Usage: jqexplore <json-file>"
		return 1
	fi
	jq -r 'paths(scalars) as $p | "\($p | join(".")) = \(getpath($p))"' "$file" | fzf --height 40% --prompt "JSON Path> "
}
json2yaml () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		yq -o=yaml .
	else
		yq -o=yaml . "$file"
	fi
}
jsonminify () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		jq -c .
	else
		jq -c . "$file"
	fi
}
jsonpretty () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		jq .
	else
		jq . "$file"
	fi
}
kbhelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE
  k         → kubectl
  kg        → kubectl get
  kgp       → pods
  kgs       → services
  kgn       → nodes
  kgi       → ingress
  kge       → events sorted by time

DESCRIBE
  kd X      → kubectl describe X
  kdp X     → describe pod
  kds X     → describe service

APPLY / DELETE / EDIT / LOGS / EXEC
  ka file   → apply -f file
  kdel file → delete -f file
  ke X      → edit resource
  kl X      → logs
  klf X     → logs -f
  kex X     → exec -it X sh

CONTEXTS / NAMESPACES
  kctx      → switch context
  kctxs     → list contexts
  kns ns    → set namespace
  knss      → list namespaces

ROLLOUTS
  krs X     → rollout status
  kru X     → rollout undo
  krr X     → rollout restart

APPLY YAML FROM CLIPBOARD
  kapplycb  → apply current clipboard contents

FZF UI HELPERS
  kpsh      → pick pod → exec shell
  kplog     → pick pod → tail logs
  knsp      → pick namespace
  kdpick    → pick deployment → describe
  kdelp     → pick pod → delete
EOF
) 
	_show_help "Kubernetes Shortcuts" "$help_content"
}
kdelp () {
	local pod
	pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" \
    | fzf --height 40%)  || return
	kubectl delete pod "$pod"
}
kdpick () {
	local dep
	dep=$(kubectl get deploy --no-headers -o custom-columns=":metadata.name" \
    | fzf --height 40% --preview 'kubectl describe deploy {}')  || return
	kubectl describe deploy "$dep"
}
kill9pick () {
	local pid
	pid=$(ps aux | tail -n +2 \
    | fzf --height 40% --prompt "Force Kill Process> " \
        --header "Select process to force kill" \
        --preview "echo {}" | awk '{print $2}')  || return
	if [[ -n "$pid" ]]
	then
		echo "Force kill process $pid?"
		read "?Confirm (y/N): " answer
		if [[ "$answer" == "y" || "$answer" == "Y" ]]
		then
			kill -9 "$pid"
			echo "Force killed process $pid"
		else
			echo "Cancelled"
		fi
	fi
}
killpick () {
	local pid
	pid=$(ps aux | tail -n +2 \
    | fzf --height 40% --prompt "Kill Process> " \
        --header "Select process to kill" \
        --preview "echo {}" | awk '{print $2}')  || return
	if [[ -n "$pid" ]]
	then
		echo "Kill process $pid?"
		read "?Confirm (y/N): " answer
		if [[ "$answer" == "y" || "$answer" == "Y" ]]
		then
			kill "$pid"
			echo "Killed process $pid"
		else
			echo "Cancelled"
		fi
	fi
}
killport () {
	local port="${1}" 
	if [[ -z "$port" ]]
	then
		echo "Usage: killport <port>"
		return 1
	fi
	local pids=$(lsof -ti:$port 2>/dev/null) 
	if [[ -z "$pids" ]]
	then
		echo "No process found on port $port"
		return 1
	fi
	echo "Processes on port $port:"
	lsof -i:$port
	echo ""
	echo -n "Kill these processes? (y/N): "
	read answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		echo "$pids" | xargs kill -9
		echo "Killed processes on port $port"
	else
		echo "Cancelled"
	fi
}
knsp () {
	local ns
	ns=$(kubectl get ns --no-headers -o custom-columns=":metadata.name" \
    | fzf --height 40%)  || return
	kubectl config set-context --current --namespace "$ns"
}
kplog () {
	local pod
	pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" \
    | fzf --height 40% --preview 'kubectl logs --tail=50 {}')  || return
	kubectl logs -f "$pod"
}
kpsh () {
	local pod
	pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" \
    | fzf --height 40% --preview 'kubectl describe pod {}')  || return
	kubectl exec -it "$pod" -- sh
}
linepick () {
	local file="${1}" 
	if [[ -z "$file" || ! -f "$file" ]]
	then
		echo "Usage: linepick <file>"
		return 1
	fi
	batcat "$file" | npm list -ba | fzf --height 40% --prompt "Line> " | awk '{$1=""; print substr($0,2)}'
}
load () {
	command uptime | awk -F 'load average:' '{print $2}'
}
localstack_off () {
	unset AWS_ENDPOINT_URL
}
localstack_on () {
	export AWS_ENDPOINT_URL="${LOCALSTACK_ENDPOINT_URL_ORIG}" 
}
makehelp () {
	local help_content
	help_content=$(cat <<'EOF'
MAKE CORE
  m         → make
  mb        → make build
  mc        → make clean
  mi        → make install
  mt        → make test
  mr        → make run
  md        → make dev
  mh        → make help

MAKE OPTIONS
  mj        → make -j (parallel, all cores)
  mj4       → make -j4 (4 parallel jobs)
  mn        → make -n (dry run)
  ms        → make -s (silent)
  mk        → make -k (keep going)
  mf X      → make -f X (use makefile X)

CMAKE
  cm        → cmake
  cmb       → cmake --build
  cmc       → cmake clean
  cmi       → cmake --install
  cmconf    → cmake -S . -B build
  cmgen X   → cmake -G X (generator)

NINJA
  nj        → ninja
  njb       → ninja -C build
  nc        → ninja -C build clean

MESON
  mes       → meson
  messetup  → meson setup
  mescomp   → meson compile
  mestest   → meson test
  mesinst   → meson install

AUTOTOOLS
  acconf    → autogen + configure
  acmake    → configure + make
  acinstall → configure + make + install

FZF HELPERS
  mtpick       → pick makefile target → run
  mtdrypick    → pick target → dry run
  mtlist       → list all make targets
  mvars        → show makefile variables
  cmbuild [X]  → quick cmake build (default Release)
  cmclean [X]  → clean cmake build
  cmninja [X]  → cmake with ninja generator
  mtime X      → make target with timing
  mparallel X  → make with optimal parallel jobs
  mrebuild [X] → clean and rebuild
  quickbuild   → detect build system → build
  buildinstall → build and install
EOF
) 
	_show_help "Build Systems" "$help_content"
}
mcd () {
	local dir="${1}" 
	if [[ -z "$dir" ]]
	then
		echo "Usage: mcd <directory>"
		return 1
	fi
	mkdir -p "$dir" && cd "$dir"
}
memleak () {
	local pid="${1}" 
	local interval="${2:-5}" 
	if [[ -z "$pid" ]]
	then
		echo "Usage: memleak <pid> [interval-seconds]"
		echo "Example: memleak 1234 5"
		return 1
	fi
	if ! ps -p "$pid" > /dev/null 2>&1
	then
		echo "Process $pid not found"
		return 1
	fi
	echo "Monitoring memory for PID $pid (interval: ${interval}s)"
	echo "Timestamp          RSS(KB)  VSZ(KB)  %MEM  CMD"
	echo "================================================"
	while true
	do
		if ! ps -p "$pid" > /dev/null 2>&1
		then
			echo "Process $pid terminated"
			break
		fi
		ps -p "$pid" -o lstart,rss,vsz,%mem,cmd | tail -1
		sleep "$interval"
	done
}
mempass () {
	local words="${1:-4}" 
	local wordlist="/usr/share/dict/words" 
	if [[ ! -f "$wordlist" ]]
	then
		echo "Word list not found at $wordlist"
		return 1
	fi
	shuf -n "$words" "$wordlist" | paste -sd '-' -
}
mparallel () {
	local target="${1}" 
	local jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) 
	echo "Building $target with $jobs parallel jobs..."
	make -j"$jobs" "$target"
}
mrebuild () {
	local target="${1:-all}" 
	echo "Cleaning..."
	make clean
	echo "Building $target..."
	make "$target"
}
mtdrypick () {
	if [[ ! -f Makefile && ! -f makefile && ! -f GNUmakefile ]]
	then
		echo "No Makefile found in current directory"
		return 1
	fi
	local target
	target=$(grep -E "^[a-zA-Z_-]+:" [Mm]akefile GNUmakefile 2>/dev/null | cut -d: -f1 \
    | fzf --height 40% --prompt "Dry-run Target> " \
        --preview "make -n {}")  || return
	echo "Dry-running: make $target"
	make -n "$target"
}
mtime () {
	local target="${1}" 
	if [[ -z "$target" ]]
	then
		echo "Usage: mtime <target>"
		return 1
	fi
	echo "Building with timing..."
	time make "$target"
}
mtlist () {
	if [[ ! -f Makefile && ! -f makefile && ! -f GNUmakefile ]]
	then
		echo "No Makefile found in current directory"
		return 1
	fi
	echo "Available make targets:"
	grep -E "^[a-zA-Z_-]+:" [Mm]akefile GNUmakefile 2> /dev/null | cut -d: -f1 | sort -u
}
mtpick () {
	if [[ ! -f Makefile && ! -f makefile && ! -f GNUmakefile ]]
	then
		echo "No Makefile found in current directory"
		return 1
	fi
	local target
	target=$(grep -E "^[a-zA-Z_-]+:" [Mm]akefile GNUmakefile 2>/dev/null | cut -d: -f1 \
    | fzf --height 40% --prompt "Make Target> " \
        --preview "make -n {}")  || return
	echo "Running: make $target"
	make "$target"
}
mvars () {
	if [[ ! -f Makefile && ! -f makefile && ! -f GNUmakefile ]]
	then
		echo "No Makefile found in current directory"
		return 1
	fi
	echo "Makefile variables:"
	make -pn | grep -A1 "^# makefile" | grep -v "^#\|^--" | sort -u
}
my_git_formatter () {
	emulate -L zsh
	if [[ -n $P9K_CONTENT ]]
	then
		typeset -g my_git_format=$P9K_CONTENT 
		return
	fi
	if (( $1 ))
	then
		local meta='%248F' 
		local clean='%76F' 
		local modified='%178F' 
		local untracked='%39F' 
		local conflicted='%196F' 
	else
		local meta='%244F' 
		local clean='%244F' 
		local modified='%244F' 
		local untracked='%244F' 
		local conflicted='%244F' 
	fi
	local res
	if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]
	then
		local branch=${(V)VCS_STATUS_LOCAL_BRANCH} 
		(( $#branch > 32 )) && branch[13,-13]="…" 
		res+="${clean}${(g::)POWERLEVEL9K_VCS_BRANCH_ICON}${branch//\%/%%}" 
	fi
	if [[ -n $VCS_STATUS_TAG && -z $VCS_STATUS_LOCAL_BRANCH ]]
	then
		local tag=${(V)VCS_STATUS_TAG} 
		(( $#tag > 32 )) && tag[13,-13]="…" 
		res+="${meta}#${clean}${tag//\%/%%}" 
	fi
	[[ -z $VCS_STATUS_LOCAL_BRANCH && -z $VCS_STATUS_TAG ]] && res+="${meta}@${clean}${VCS_STATUS_COMMIT[1,8]}" 
	if [[ -n ${VCS_STATUS_REMOTE_BRANCH:#$VCS_STATUS_LOCAL_BRANCH} ]]
	then
		res+="${meta}:${clean}${(V)VCS_STATUS_REMOTE_BRANCH//\%/%%}" 
	fi
	if [[ $VCS_STATUS_COMMIT_SUMMARY == (|*[^[:alnum:]])(wip|WIP)(|[^[:alnum:]]*) ]]
	then
		res+=" ${modified}wip" 
	fi
	if (( VCS_STATUS_COMMITS_AHEAD || VCS_STATUS_COMMITS_BEHIND ))
	then
		(( VCS_STATUS_COMMITS_BEHIND )) && res+=" ${clean}⇣${VCS_STATUS_COMMITS_BEHIND}" 
		(( VCS_STATUS_COMMITS_AHEAD && !VCS_STATUS_COMMITS_BEHIND )) && res+=" " 
		(( VCS_STATUS_COMMITS_AHEAD  )) && res+="${clean}⇡${VCS_STATUS_COMMITS_AHEAD}" 
	elif [[ -n $VCS_STATUS_REMOTE_BRANCH ]]
	then
		
	fi
	(( VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" ${clean}⇠${VCS_STATUS_PUSH_COMMITS_BEHIND}" 
	(( VCS_STATUS_PUSH_COMMITS_AHEAD && !VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" " 
	(( VCS_STATUS_PUSH_COMMITS_AHEAD  )) && res+="${clean}⇢${VCS_STATUS_PUSH_COMMITS_AHEAD}" 
	(( VCS_STATUS_STASHES        )) && res+=" ${clean}*${VCS_STATUS_STASHES}" 
	[[ -n $VCS_STATUS_ACTION ]] && res+=" ${conflicted}${VCS_STATUS_ACTION}" 
	(( VCS_STATUS_NUM_CONFLICTED )) && res+=" ${conflicted}~${VCS_STATUS_NUM_CONFLICTED}" 
	(( VCS_STATUS_NUM_STAGED     )) && res+=" ${modified}+${VCS_STATUS_NUM_STAGED}" 
	(( VCS_STATUS_NUM_UNSTAGED   )) && res+=" ${modified}!${VCS_STATUS_NUM_UNSTAGED}" 
	(( VCS_STATUS_NUM_UNTRACKED  )) && res+=" ${untracked}${(g::)POWERLEVEL9K_VCS_UNTRACKED_ICON}${VCS_STATUS_NUM_UNTRACKED}" 
	(( VCS_STATUS_HAS_UNSTAGED == -1 )) && res+=" ${modified}─" 
	typeset -g my_git_format=$res 
}
mycreate () {
	local dbname="${1}" 
	if [[ -z "$dbname" ]]
	then
		echo "Usage: mycreate <database-name>"
		return 1
	fi
	mysql -e "CREATE DATABASE $dbname;"
	echo "Created MySQL database: $dbname"
}
mydrop () {
	local dbname="${1}" 
	if [[ -z "$dbname" ]]
	then
		echo "Usage: mydrop <database-name>"
		return 1
	fi
	read "?Drop database '$dbname'? This cannot be undone. (y/N): " answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		mysql -e "DROP DATABASE $dbname;"
		echo "Dropped MySQL database: $dbname"
	else
		echo "Cancelled"
	fi
}
mydumppick () {
	local db
	db=$(mysql -e "SHOW DATABASES;" -s --skip-column-names \
    | grep -v 'information_schema\|performance_schema\|mysql\|sys' \
    | fzf --height 40% --prompt "Dump MySQL DB> ")  || return
	local filename="${db}_$(date +%Y%m%d_%H%M%S).sql" 
	echo "Dumping $db to $filename..."
	mysqldump "$db" > "$filename"
	echo "Done! Saved to $filename"
}
mypick () {
	local db
	db=$(mysql -e "SHOW DATABASES;" -s --skip-column-names \
    | grep -v 'information_schema\|performance_schema\|mysql\|sys' \
    | fzf --height 40% --prompt "MySQL DB> ")  || return
	mysql "$db"
}
myports () {
	echo "Ports opened by your processes:"
	ss -tulnp | grep "$(whoami)"
}
myptree () {
	pstree -p -p "$(whoami)"
}
mytables () {
	local db="${1}" 
	if [[ -z "$db" ]]
	then
		echo "Usage: mytables <database-name>"
		return 1
	fi
	mysql "$db" -e "
    SELECT
      table_name AS 'Table',
      ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
    FROM information_schema.TABLES
    WHERE table_schema = '$db'
    ORDER BY (data_length + index_length) DESC;
  "
}
nethelp () {
	local help_content
	help_content=$(cat <<'EOF'
CONNECTION TESTING
  p X       → ping X
  p4 X      → ping X (4 times)
  p8        → ping 8.8.8.8

HTTP REQUESTS
  get X     → curl -X GET X
  post X    → curl -X POST X
  put X     → curl -X PUT X
  del X     → curl -X DELETE X
  curlj     → curl with JSON content-type
  curljson  → curl with JSON headers
  curlt X   → curl X with timing

DNS LOOKUPS
  diga X    → dig A record
  digaaaa X → dig AAAA record
  digmx X   → dig MX record
  digns X   → dig NS record
  digtxt X  → dig TXT record
  digall X  → dig all answers
  digtrace X→ dig with trace

IP INFORMATION
  myip      → show public IP
  myip4     → show public IPv4
  myip6     → show public IPv6
  localip   → show local IP addresses

PORTS & CONNECTIONS
  ports     → show all ports (netstat)
  listening → show listening ports
  established → show established connections

NETWORK STATS
  netstat-summary → connection summary
  netstats        → watch connection stats

INTERFACES
  ifaces    → show interfaces (brief)
  ifup X    → bring interface X up
  ifdown X  → bring interface X down

ROUTING
  routes    → show routing table
  route4    → show IPv4 routes
  route6    → show IPv6 routes
  addroute  → add route
  delroute  → delete route

ARP
  arp-scan  → scan local network
  arp-table → show ARP table

FIREWALL
  fwlist    → list iptables rules
  fwlist6   → list ip6tables rules

FZF UI HELPERS
  ifpick       → pick interface → show details
  portpick     → pick port → show process
  connpick     → pick connection → show details
  pingmulti    → ping multiple common hosts
  portscan X [Y] [Z] → scan ports on host X
  httpstatus X → check HTTP status of URL X
  checkport X Y→ check if port Y on host X is open
  digfull X    → full DNS lookup for domain X
  bandwidth [X]→ monitor bandwidth on interface X
  trace [X]    → traceroute to host X
  myports      → show ports opened by your processes
EOF
) 
	_show_help "Network Tools" "$help_content"
}
netiostat () {
	sar -n DEV 2 5 2> /dev/null || echo "sar not installed. Install with: sudo dnf install sysstat"
}
netmon () {
	if ! command -v iftop > /dev/null 2>&1
	then
		echo "iftop not installed"
		echo "Install with: sudo dnf install iftop"
		echo ""
		echo "Alternative: using watch + ip"
		watch -n 1 "ip -s link"
		return
	fi
	echo "Network traffic monitor (requires sudo)"
	sudo iftop
}
newproject () {
	local name="${1}" 
	local type="${2:-general}" 
	if [[ -z "$name" ]]
	then
		echo "Usage: newproject <name> [type]"
		echo "Types: python, node, go, rust, general (default)"
		return 1
	fi
	mkdir -p "$name"
	cd "$name"
	mkdir -p src tests docs
	git init
	batcat > README.md <<EOF
# $name

## Description
TODO: Add project description

## Installation
TODO: Add installation instructions

## Usage
TODO: Add usage instructions

## Development
TODO: Add development instructions

## License
MIT
EOF
	case "$type" in
		(python) batcat > .gitignore <<EOF
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
.env
.venv
env/
venv/
ENV/
.pytest_cache/
.coverage
htmlcov/
.mypy_cache/
.ruff_cache/
EOF
			touch requirements.txt
			touch pyproject.toml
			mkdir -p src/"$name"
			touch src/"$name"/__init__.py
			echo "Python project created. Run 'python -m venv .venv' to create virtual environment" ;;
		(node) batcat > .gitignore <<EOF
node_modules/
npm-debug.log
yarn-error.log
.env
.env.local
dist/
build/
coverage/
.DS_Store
*.log
EOF
			npm init -y
			echo "Node.js project created. Run 'npm install' to add dependencies" ;;
		(go) batcat > .gitignore <<EOF
# Binaries
*.exe
*.exe~
*.dll
*.so
*.dylib
bin/
dist/

# Test binary
*.test

# Output of the go coverage tool
*.out

# Go workspace file
go.work

# Env files
.env
EOF
			go mod init "$name"
			mkdir -p cmd/"$name"
			batcat > cmd/"$name"/main.go <<EOF
package main

import "fmt"

func main() {
    fmt.Println("Hello, $name!")
}
EOF
			echo "Go project created. Run 'go build ./cmd/$name' to build" ;;
		(rust) cargo init --name "$name" ;;
		(*) batcat > .gitignore <<EOF ;;
# General
.DS_Store
*.log
*.swp
*.swo
*~
.env
.env.local

# IDE
.idea/
.vscode/
*.iml

# Build
build/
dist/
target/
out/
EOF
	esac
	echo ""
	echo "Project '$name' created successfully!"
	echo "Location: $(pwd)"
	lsd -la
}
ninfo () {
	local pkg="${1}" 
	if [[ -z "$pkg" ]]
	then
		pkg=$(npm list --depth=0 | tail -n +2 | awk '{print $2}' | cut -d@ -f1 \
      | fzf --height 40% --prompt "Package Info> ")  || return
	fi
	npm info "$pkg"
}
nodehelp () {
	local help_content
	help_content=$(cat <<'EOF'
NPM CORE
  n         → npm
  ni        → npm install
  nid       → npm install --save-dev
  nig       → npm install -g
  nu        → npm uninstall
  nug       → npm uninstall -g
  nup       → npm update
  nr X      → npm run X
  ns        → npm start
  nt        → npm test
  nb        → npm run build
  nd        → npm run dev

NPM PACKAGE MANAGEMENT
  nl        → npm list
  nls       → npm list --depth=0
  no        → npm outdated
  ncc       → npm cache clean --force
  ninit     → npm init -y
  npub      → npm publish

NPM SCRIPTS (COMMON)
  nrd       → npm run dev
  nrb       → npm run build
  nrt       → npm run test
  nrl       → npm run lint
  nrf       → npm run format

YARN
  y         → yarn
  ya X      → yarn add X
  yad X     → yarn add --dev X
  yag X     → yarn global add X
  yr X      → yarn remove X
  yup       → yarn upgrade
  ys        → yarn start
  yt        → yarn test
  yb        → yarn build
  yd        → yarn dev
  yout      → yarn outdated

NVM (NODE VERSION MANAGER)
  nvml      → nvm list
  nvmi X    → nvm install X
  nvmu X    → nvm use X
  nvmcur    → nvm current
  nvmd      → nvm use default

FZF UI HELPERS
  nrpick    → pick package.json script → run
  nvmpick   → pick node version → use
  nugpick   → pick global package → uninstall
  nupick    → pick local package → uninstall
  nquick    → quick npm init with eslint + prettier
  ninfo [pkg] → show package info (fzf if no arg)
EOF
) 
	_show_help "Node.js Tools" "$help_content"
}
nquick () {
	local name="${1:-.}" 
	if [[ "$name" != "." ]]
	then
		mkdir -p "$name" || return 1
		cd "$name"
	fi
	npm init -y
	npm install --save-dev eslint prettier
	echo "Initialized npm project with eslint and prettier"
}
nrpick () {
	if [[ ! -f package.json ]]
	then
		echo "No package.json found in current directory"
		return 1
	fi
	local script
	script=$(jq -r '.scripts | keys[]' package.json 2>/dev/null \
    | fzf --height 40% --prompt "NPM Script> " \
        --preview "jq -r '.scripts.\"{}\"' package.json")  || return
	echo "Running: npm run $script"
	npm run "$script"
}
nugpick () {
	local pkg
	pkg=$(npm list -g --depth=0 | tail -n +2 | awk '{print $2}' | cut -d@ -f1 \
    | fzf --height 40% --prompt "Uninstall Global Package> " \
        --preview "npm list -g {} --depth=0")  || return
	npm uninstall -g "$pkg"
}
nupick () {
	if [[ ! -f package.json ]]
	then
		echo "No package.json found in current directory"
		return 1
	fi
	local pkg
	pkg=$(jq -r '.dependencies // {}, .devDependencies // {} | keys[]' package.json 2>/dev/null \
    | fzf --height 40% --prompt "Uninstall Package> " \
        --preview "npm info {}")  || return
	npm uninstall "$pkg"
}
nvm () {
	if [ "$#" -lt 1 ]
	then
		nvm --help
		return
	fi
	local DEFAULT_IFS
	DEFAULT_IFS=" $(nvm_echo t | command tr t \\t)
" 
	if [ "${-#*e}" != "$-" ]
	then
		set +e
		local EXIT_CODE
		IFS="${DEFAULT_IFS}" nvm "$@"
		EXIT_CODE="$?" 
		set -e
		return "$EXIT_CODE"
	elif [ "${-#*a}" != "$-" ]
	then
		set +a
		local EXIT_CODE
		IFS="${DEFAULT_IFS}" nvm "$@"
		EXIT_CODE="$?" 
		set -a
		return "$EXIT_CODE"
	elif [ -n "${BASH-}" ] && [ "${-#*E}" != "$-" ]
	then
		set +E
		local EXIT_CODE
		IFS="${DEFAULT_IFS}" nvm "$@"
		EXIT_CODE="$?" 
		set -E
		return "$EXIT_CODE"
	elif [ "${IFS}" != "${DEFAULT_IFS}" ]
	then
		IFS="${DEFAULT_IFS}" nvm "$@"
		return "$?"
	fi
	local i
	for i in "$@"
	do
		case $i in
			(--) break ;;
			('-h' | 'help' | '--help') NVM_NO_COLORS="" 
				for j in "$@"
				do
					if [ "${j}" = '--no-colors' ]
					then
						NVM_NO_COLORS="${j}" 
						break
					fi
				done
				local NVM_IOJS_PREFIX
				NVM_IOJS_PREFIX="$(nvm_iojs_prefix)" 
				local NVM_NODE_PREFIX
				NVM_NODE_PREFIX="$(nvm_node_prefix)" 
				NVM_VERSION="$(nvm --version)" 
				nvm_echo
				nvm_echo "Node Version Manager (v${NVM_VERSION})"
				nvm_echo
				nvm_echo 'Note: <version> refers to any version-like string nvm understands. This includes:'
				nvm_echo '  - full or partial version numbers, starting with an optional "v" (0.10, v0.1.2, v1)'
				nvm_echo "  - default (built-in) aliases: ${NVM_NODE_PREFIX}, stable, unstable, ${NVM_IOJS_PREFIX}, system"
				nvm_echo '  - custom aliases you define with `nvm alias foo`'
				nvm_echo
				nvm_echo ' Any options that produce colorized output should respect the `--no-colors` option.'
				nvm_echo
				nvm_echo 'Usage:'
				nvm_echo '  nvm --help                                  Show this message'
				nvm_echo '    --no-colors                               Suppress colored output'
				nvm_echo '  nvm --version                               Print out the installed version of nvm'
				nvm_echo '  nvm install [<version>]                     Download and install a <version>. Uses .nvmrc if version is omitted; otherwise errors.'
				nvm_echo '   The following optional arguments, if provided, must appear directly after `nvm install`:'
				nvm_echo '    -s                                        Skip binary download, install from source only.'
				nvm_echo '    -b                                        Skip source download, install from binary only.'
				nvm_echo '    --reinstall-packages-from=<version>       When installing, reinstall packages installed in <node|iojs|node version number>'
				nvm_echo '    --lts                                     When installing, only select from LTS (long-term support) versions'
				nvm_echo '    --lts=<LTS name>                          When installing, only select from versions for a specific LTS line'
				nvm_echo '    --skip-default-packages                   When installing, skip the default-packages file if it exists'
				nvm_echo '    --latest-npm                              After installing, attempt to upgrade to the latest working npm on the given node version'
				nvm_echo '    --no-progress                             Disable the progress bar on any downloads'
				nvm_echo '    --offline                                 Install from cache only, without downloading anything'
				nvm_echo '    --alias=<name>                            After installing, set the alias specified to the version specified. (same as: nvm alias <name> <version>)'
				nvm_echo '    --default                                 After installing, set default alias to the version specified. (same as: nvm alias default <version>)'
				nvm_echo '    --save                                    After installing, write the specified version to .nvmrc'
				nvm_echo '  nvm uninstall <version>                     Uninstall a version'
				nvm_echo '  nvm uninstall --lts                         Uninstall using automatic LTS (long-term support) alias `lts/*`, if available.'
				nvm_echo '  nvm uninstall --lts=<LTS name>              Uninstall using automatic alias for provided LTS line, if available.'
				nvm_echo '  nvm use [current | <version>]               Modify PATH to use <version>. Uses .nvmrc if version is omitted; otherwise errors.'
				nvm_echo '   The following optional arguments, if provided, must appear directly after `nvm use`:'
				nvm_echo '    --silent                                  Silences stdout/stderr output'
				nvm_echo '    --lts                                     Uses automatic LTS (long-term support) alias `lts/*`, if available.'
				nvm_echo '    --lts=<LTS name>                          Uses automatic alias for provided LTS line, if available.'
				nvm_echo '    --save                                    Writes the specified version to .nvmrc.'
				nvm_echo '  nvm exec [current | <version>] [<command>]  Run <command> on <version>. Uses .nvmrc if version is omitted; otherwise errors.'
				nvm_echo '   The following optional arguments, if provided, must appear directly after `nvm exec`:'
				nvm_echo '    --silent                                  Silences stdout/stderr output'
				nvm_echo '    --lts                                     Uses automatic LTS (long-term support) alias `lts/*`, if available.'
				nvm_echo '    --lts=<LTS name>                          Uses automatic alias for provided LTS line, if available.'
				nvm_echo '  nvm run [current | <version>] [<args>]      Run `node` on <version> with <args> as arguments. Uses .nvmrc if version is omitted; otherwise errors.'
				nvm_echo '   The following optional arguments, if provided, must appear directly after `nvm run`:'
				nvm_echo '    --silent                                  Silences stdout/stderr output'
				nvm_echo '    --lts                                     Uses automatic LTS (long-term support) alias `lts/*`, if available.'
				nvm_echo '    --lts=<LTS name>                          Uses automatic alias for provided LTS line, if available.'
				nvm_echo '  nvm current                                 Display the active node version (resolved via $PATH; not affected by .nvmrc).'
				nvm_echo '  nvm ls [<version>]                          List installed versions, matching a given <version> if provided'
				nvm_echo '    --no-colors                               Suppress colored output'
				nvm_echo '    --no-alias                                Suppress `nvm alias` output'
				nvm_echo '  nvm ls-remote [<version>]                   List remote versions available for install, matching a given <version> if provided'
				nvm_echo '    --lts                                     When listing, only show LTS (long-term support) versions'
				nvm_echo '    --lts=<LTS name>                          When listing, only show versions for a specific LTS line'
				nvm_echo '    --no-colors                               Suppress colored output'
				nvm_echo '  nvm version <version>                       Resolve the given description to a single local version'
				nvm_echo '  nvm version-remote <version>                Resolve the given description to a single remote version'
				nvm_echo '    --lts                                     When listing, only select from LTS (long-term support) versions'
				nvm_echo '    --lts=<LTS name>                          When listing, only select from versions for a specific LTS line'
				nvm_echo '  nvm deactivate                              Undo effects of `nvm` on current shell'
				nvm_echo '    --silent                                  Silences stdout/stderr output'
				nvm_echo '  nvm alias [<pattern>]                       Show all aliases beginning with <pattern>'
				nvm_echo '    --no-colors                               Suppress colored output'
				nvm_echo '  nvm alias <name> <version>                  Set an alias named <name> pointing to <version>'
				nvm_echo '  nvm unalias <name>                          Deletes the alias named <name>'
				nvm_echo '  nvm install-latest-npm                      Attempt to upgrade to the latest working `npm` on the current node version'
				nvm_echo '  nvm reinstall-packages <version>            Reinstall global `npm` packages contained in <version> to current version'
				nvm_echo '  nvm unload                                  Unload `nvm` from shell'
				nvm_echo '  nvm which [current | <version>]             Display path to installed node version. Uses .nvmrc if version is omitted; otherwise errors.'
				nvm_echo '    --silent                                  Silences stdout/stderr output when a version is omitted'
				nvm_echo '  nvm cache dir                               Display path to the cache directory for nvm'
				nvm_echo '  nvm cache clear                             Empty cache directory for nvm'
				nvm_echo '  nvm set-colors [<color codes>]              Set five text colors using format "yMeBg". Available when supported.'
				nvm_echo '                                               Initial colors are:'
				nvm_echo_with_colors "                                                  $(nvm_wrap_with_color_code 'b' 'b')$(nvm_wrap_with_color_code 'y' 'y')$(nvm_wrap_with_color_code 'g' 'g')$(nvm_wrap_with_color_code 'r' 'r')$(nvm_wrap_with_color_code 'e' 'e')"
				nvm_echo '                                               Color codes:'
				nvm_echo_with_colors "                                                $(nvm_wrap_with_color_code 'r' 'r')/$(nvm_wrap_with_color_code 'R' 'R') = $(nvm_wrap_with_color_code 'r' 'red') / $(nvm_wrap_with_color_code 'R' 'bold red')"
				nvm_echo_with_colors "                                                $(nvm_wrap_with_color_code 'g' 'g')/$(nvm_wrap_with_color_code 'G' 'G') = $(nvm_wrap_with_color_code 'g' 'green') / $(nvm_wrap_with_color_code 'G' 'bold green')"
				nvm_echo_with_colors "                                                $(nvm_wrap_with_color_code 'b' 'b')/$(nvm_wrap_with_color_code 'B' 'B') = $(nvm_wrap_with_color_code 'b' 'blue') / $(nvm_wrap_with_color_code 'B' 'bold blue')"
				nvm_echo_with_colors "                                                $(nvm_wrap_with_color_code 'c' 'c')/$(nvm_wrap_with_color_code 'C' 'C') = $(nvm_wrap_with_color_code 'c' 'cyan') / $(nvm_wrap_with_color_code 'C' 'bold cyan')"
				nvm_echo_with_colors "                                                $(nvm_wrap_with_color_code 'm' 'm')/$(nvm_wrap_with_color_code 'M' 'M') = $(nvm_wrap_with_color_code 'm' 'magenta') / $(nvm_wrap_with_color_code 'M' 'bold magenta')"
				nvm_echo_with_colors "                                                $(nvm_wrap_with_color_code 'y' 'y')/$(nvm_wrap_with_color_code 'Y' 'Y') = $(nvm_wrap_with_color_code 'y' 'yellow') / $(nvm_wrap_with_color_code 'Y' 'bold yellow')"
				nvm_echo_with_colors "                                                $(nvm_wrap_with_color_code 'k' 'k')/$(nvm_wrap_with_color_code 'K' 'K') = $(nvm_wrap_with_color_code 'k' 'black') / $(nvm_wrap_with_color_code 'K' 'bold black')"
				nvm_echo_with_colors "                                                $(nvm_wrap_with_color_code 'e' 'e')/$(nvm_wrap_with_color_code 'W' 'W') = $(nvm_wrap_with_color_code 'e' 'light grey') / $(nvm_wrap_with_color_code 'W' 'white')"
				nvm_echo 'Example:'
				nvm_echo '  nvm install 8.0.0                     Install a specific version number'
				nvm_echo '  nvm use 8.0                           Use the latest available 8.0.x release'
				nvm_echo '  nvm run 6.10.3 app.js                 Run app.js using node 6.10.3'
				nvm_echo '  nvm exec 4.8.3 node app.js            Run `node app.js` with the PATH pointing to node 4.8.3'
				nvm_echo '  nvm alias default 8.1.0               Set default node version on a shell'
				nvm_echo '  nvm alias default node                Always default to the latest available node version on a shell'
				nvm_echo
				nvm_echo '  nvm install node                      Install the latest available version'
				nvm_echo '  nvm use node                          Use the latest version'
				nvm_echo '  nvm install --lts                     Install the latest LTS version'
				nvm_echo '  nvm use --lts                         Use the latest LTS version'
				nvm_echo
				nvm_echo '  nvm set-colors cgYmW                  Set text colors to cyan, green, bold yellow, magenta, and white'
				nvm_echo
				nvm_echo 'Note:'
				nvm_echo '  to remove, delete, or uninstall nvm - just remove the `$NVM_DIR` folder (usually `~/.nvm`)'
				nvm_echo
				return 0 ;;
		esac
	done
	local COMMAND
	COMMAND="${1-}" 
	shift
	local VERSION
	local ADDITIONAL_PARAMETERS
	case $COMMAND in
		("cache") case "${1-}" in
				(dir) nvm_cache_dir ;;
				(clear) local DIR
					DIR="$(nvm_cache_dir)" 
					if command rm -rf "${DIR}" && command mkdir -p "${DIR}"
					then
						nvm_echo 'nvm cache cleared.'
					else
						nvm_err "Unable to clear nvm cache: ${DIR}"
						return 1
					fi ;;
				(*) nvm_err 'Usage: nvm cache dir'
					nvm_err '       nvm cache clear'
					nvm_err '  Run `nvm --help` for full help.'
					return 127 ;;
			esac ;;
		("debug") local OS_VERSION
			nvm_is_zsh && setopt local_options shwordsplit
			nvm_err "nvm --version: v$(nvm --version)"
			if [ -n "${TERM_PROGRAM-}" ]
			then
				nvm_err "\$TERM_PROGRAM: ${TERM_PROGRAM}"
			fi
			nvm_err "\$SHELL: ${SHELL}"
			nvm_err "\$SHLVL: ${SHLVL-}"
			nvm_err "whoami: '$(whoami)'"
			nvm_err "\${HOME}: ${HOME}"
			nvm_err "\${NVM_DIR}: '$(nvm_sanitize_path "${NVM_DIR}")'"
			nvm_err "\${PATH}: $(nvm_sanitize_path "${PATH}")"
			nvm_err "\$PREFIX: '$(nvm_sanitize_path "${PREFIX-}")'"
			nvm_err "\${NPM_CONFIG_PREFIX}: '$(nvm_sanitize_path "${NPM_CONFIG_PREFIX-}")'"
			nvm_err "\$NVM_NODEJS_ORG_MIRROR: '${NVM_NODEJS_ORG_MIRROR-}'"
			nvm_err "\$NVM_IOJS_ORG_MIRROR: '${NVM_IOJS_ORG_MIRROR-}'"
			nvm_err "shell version: '$(${SHELL} --version | command head -n 1)'"
			nvm_err "uname -a: '$(command uname -a | command awk '{$2=""; print}' | command xargs)'"
			nvm_err "checksum binary: '$(nvm_get_checksum_binary 2>/dev/null)'"
			if [ "$(nvm_get_os)" = "darwin" ] && nvm_has sw_vers
			then
				OS_VERSION="$(sw_vers | command awk '{print $2}' | command xargs)" 
			elif [ -r "/etc/issue" ]
			then
				OS_VERSION="$(command head -n 1 /etc/issue | command sed 's/\\.//g')" 
				if [ -z "${OS_VERSION}" ] && [ -r "/etc/os-release" ]
				then
					OS_VERSION="$(. /etc/os-release && echo "${NAME}" "${VERSION}")" 
				fi
			fi
			if [ -n "${OS_VERSION}" ]
			then
				nvm_err "OS version: ${OS_VERSION}"
			fi
			if nvm_has "awk"
			then
				nvm_err "awk: $(nvm_command_info awk), $({ command awk --version 2>/dev/null || command awk -W version; } \
          | command head -n 1)"
			else
				nvm_err "awk: not found"
			fi
			if nvm_has "curl"
			then
				nvm_err "curl: $(nvm_command_info curl), $(command curl -V | command head -n 1)"
			else
				nvm_err "curl: not found"
			fi
			if nvm_has "wget"
			then
				nvm_err "wget: $(nvm_command_info wget), $(command wget -V | command head -n 1)"
			else
				nvm_err "wget: not found"
			fi
			local TEST_TOOLS ADD_TEST_TOOLS
			TEST_TOOLS="git grep" 
			ADD_TEST_TOOLS="sed cut basename rm mkdir xargs" 
			if [ "darwin" != "$(nvm_get_os)" ] && [ "freebsd" != "$(nvm_get_os)" ]
			then
				TEST_TOOLS="${TEST_TOOLS} ${ADD_TEST_TOOLS}" 
			else
				for tool in ${ADD_TEST_TOOLS}
				do
					if nvm_has "${tool}"
					then
						nvm_err "${tool}: $(nvm_command_info "${tool}")"
					else
						nvm_err "${tool}: not found"
					fi
				done
			fi
			for tool in ${TEST_TOOLS}
			do
				local NVM_TOOL_VERSION
				if nvm_has "${tool}"
				then
					if command ls -l "$(nvm_command_info "${tool}" | command awk '{print $1}')" | command grep -q busybox
					then
						NVM_TOOL_VERSION="$(command "${tool}" --help 2>&1 | command head -n 1)" 
					else
						NVM_TOOL_VERSION="$(command "${tool}" --version 2>&1 | command head -n 1)" 
					fi
					nvm_err "${tool}: $(nvm_command_info "${tool}"), ${NVM_TOOL_VERSION}"
				else
					nvm_err "${tool}: not found"
				fi
				unset NVM_TOOL_VERSION
			done
			unset TEST_TOOLS ADD_TEST_TOOLS
			local NVM_DEBUG_OUTPUT
			for NVM_DEBUG_COMMAND in 'nvm current' 'which node' 'which iojs' 'which npm' 'npm config get prefix' 'npm root -g'
			do
				NVM_DEBUG_OUTPUT="$(${NVM_DEBUG_COMMAND} 2>&1)" 
				nvm_err "${NVM_DEBUG_COMMAND}: $(nvm_sanitize_path "${NVM_DEBUG_OUTPUT}")"
			done
			return 42 ;;
		("install" | "i") local version_not_provided
			version_not_provided=0 
			local NVM_OS
			NVM_OS="$(nvm_get_os)" 
			if [ $# -lt 1 ]
			then
				version_not_provided=1 
			fi
			local nobinary
			local nosource
			local noprogress
			local NVM_OFFLINE
			nobinary=0 
			noprogress=0 
			nosource=0 
			NVM_OFFLINE=0 
			local LTS
			local ALIAS
			local NVM_UPGRADE_NPM
			NVM_UPGRADE_NPM=0 
			local NVM_WRITE_TO_NVMRC
			NVM_WRITE_TO_NVMRC=0 
			local PROVIDED_REINSTALL_PACKAGES_FROM
			local REINSTALL_PACKAGES_FROM
			local SKIP_DEFAULT_PACKAGES
			while [ $# -ne 0 ]
			do
				case "$1" in
					(---*) nvm_err 'arguments with `---` are not supported - this is likely a typo'
						return 55 ;;
					(-s) shift
						nobinary=1 
						if [ $nosource -eq 1 ]
						then
							nvm_err '-s and -b cannot be set together since they would skip install from both binary and source'
							return 6
						fi ;;
					(-b) shift
						nosource=1 
						if [ $nobinary -eq 1 ]
						then
							nvm_err '-s and -b cannot be set together since they would skip install from both binary and source'
							return 6
						fi ;;
					(-j) shift
						nvm_get_make_jobs "$1"
						shift ;;
					(--no-progress) noprogress=1 
						shift ;;
					(--offline) NVM_OFFLINE=1 
						shift ;;
					(--lts) LTS='*' 
						shift ;;
					(--lts=*) LTS="${1##--lts=}" 
						shift ;;
					(--latest-npm) NVM_UPGRADE_NPM=1 
						shift ;;
					(--default) if [ -n "${ALIAS-}" ]
						then
							nvm_err '--default and --alias are mutually exclusive, and may not be provided more than once'
							return 6
						fi
						ALIAS='default' 
						shift ;;
					(--alias=*) if [ -n "${ALIAS-}" ]
						then
							nvm_err '--default and --alias are mutually exclusive, and may not be provided more than once'
							return 6
						fi
						ALIAS="${1##--alias=}" 
						shift ;;
					(--reinstall-packages-from=*) if [ -n "${PROVIDED_REINSTALL_PACKAGES_FROM-}" ]
						then
							nvm_err '--reinstall-packages-from may not be provided more than once'
							return 6
						fi
						PROVIDED_REINSTALL_PACKAGES_FROM="$(nvm_echo "$1" | command cut -c 27-)" 
						if [ -z "${PROVIDED_REINSTALL_PACKAGES_FROM}" ]
						then
							nvm_err 'If --reinstall-packages-from is provided, it must point to an installed version of node.'
							return 6
						fi
						REINSTALL_PACKAGES_FROM="$(nvm_version "${PROVIDED_REINSTALL_PACKAGES_FROM}")"  || :
						shift ;;
					(--copy-packages-from=*) if [ -n "${PROVIDED_REINSTALL_PACKAGES_FROM-}" ]
						then
							nvm_err '--reinstall-packages-from may not be provided more than once, or combined with `--copy-packages-from`'
							return 6
						fi
						PROVIDED_REINSTALL_PACKAGES_FROM="$(nvm_echo "$1" | command cut -c 22-)" 
						if [ -z "${PROVIDED_REINSTALL_PACKAGES_FROM}" ]
						then
							nvm_err 'If --copy-packages-from is provided, it must point to an installed version of node.'
							return 6
						fi
						REINSTALL_PACKAGES_FROM="$(nvm_version "${PROVIDED_REINSTALL_PACKAGES_FROM}")"  || :
						shift ;;
					(--reinstall-packages-from | --copy-packages-from) nvm_err "If ${1} is provided, it must point to an installed version of node using \`=\`."
						return 6 ;;
					(--skip-default-packages) SKIP_DEFAULT_PACKAGES=true 
						shift ;;
					(--save | -w) if [ $NVM_WRITE_TO_NVMRC -eq 1 ]
						then
							nvm_err '--save and -w may only be provided once'
							return 6
						fi
						NVM_WRITE_TO_NVMRC=1 
						shift ;;
					(*) break ;;
				esac
			done
			if [ "${NVM_OFFLINE}" != 1 ] && ! nvm_has_executable "curl" && ! nvm_has_executable "wget"
			then
				nvm_err 'nvm needs curl or wget to proceed.'
				return 1
			fi
			local provided_version
			provided_version="${1-}" 
			if [ -z "${provided_version}" ]
			then
				if [ "_${LTS-}" = '_*' ]
				then
					nvm_echo 'Installing latest LTS version.'
					if [ $# -gt 0 ]
					then
						shift
					fi
				elif [ "_${LTS-}" != '_' ]
				then
					nvm_echo "Installing with latest version of LTS line: ${LTS}"
					if [ $# -gt 0 ]
					then
						shift
					fi
				else
					{
						provided_version="$(nvm_rc_version 3>&1 1>&4)" 
					} 4>&1
					if [ $version_not_provided -eq 1 ] && [ -z "${provided_version}" ]
					then
						nvm_err 'Usage: nvm install [<version>]'
						nvm_err '  Provide a <version>, or run from a directory containing an .nvmrc file.'
						nvm_err '  Run `nvm --help` for full help.'
						return 127
					fi
				fi
			elif [ $# -gt 0 ]
			then
				shift
			fi
			case "${provided_version}" in
				('lts/*') LTS='*' 
					provided_version=''  ;;
				(lts/*) LTS="${provided_version##lts/}" 
					provided_version=''  ;;
			esac
			local EXIT_CODE
			if [ "${NVM_OFFLINE}" = 1 ]
			then
				local OFFLINE_PATTERN
				OFFLINE_PATTERN="${provided_version}" 
				if [ -n "${LTS-}" ]
				then
					if [ "${LTS}" = '*' ]
					then
						OFFLINE_PATTERN="$(nvm_resolve_alias 'lts/*' 2>/dev/null || nvm_echo)" 
					else
						OFFLINE_PATTERN="$(nvm_resolve_alias "lts/${LTS}" 2>/dev/null || nvm_echo)" 
					fi
					if [ -z "${OFFLINE_PATTERN}" ]
					then
						nvm_err "LTS alias '${LTS}' not found locally. Run \`nvm ls-remote --lts\` first to populate LTS aliases."
						return 3
					fi
				fi
				VERSION="$(nvm_offline_version "${OFFLINE_PATTERN}")" 
				EXIT_CODE="$?" 
			else
				VERSION="$(NVM_VERSION_ONLY=true NVM_LTS="${LTS-}" nvm_remote_version "${provided_version}")" 
				EXIT_CODE="$?" 
			fi
			if [ "${VERSION}" = 'N/A' ] || [ $EXIT_CODE -ne 0 ]
			then
				local LTS_MSG
				local REMOTE_CMD
				if [ "${LTS-}" = '*' ]
				then
					LTS_MSG='(with LTS filter) ' 
					REMOTE_CMD='nvm ls-remote --lts' 
				elif [ -n "${LTS-}" ]
				then
					LTS_MSG="(with LTS filter '${LTS}') " 
					REMOTE_CMD="nvm ls-remote --lts=${LTS}" 
					if [ -z "${provided_version}" ]
					then
						nvm_err "Version with LTS filter '${LTS}' not found - try \`${REMOTE_CMD}\` to browse available versions."
						return 3
					fi
				else
					if [ "${NVM_OFFLINE}" = 1 ]
					then
						REMOTE_CMD='nvm ls' 
					else
						REMOTE_CMD='nvm ls-remote' 
					fi
				fi
				if [ "${NVM_OFFLINE}" = 1 ]
				then
					nvm_err "Version '${provided_version}' ${LTS_MSG-}not found locally or in cache - try \`${REMOTE_CMD}\` to browse available versions."
				else
					nvm_err "Version '${provided_version}' ${LTS_MSG-}not found - try \`${REMOTE_CMD}\` to browse available versions."
				fi
				return 3
			fi
			ADDITIONAL_PARAMETERS='' 
			while [ $# -ne 0 ]
			do
				case "$1" in
					(--reinstall-packages-from=*) if [ -n "${PROVIDED_REINSTALL_PACKAGES_FROM-}" ]
						then
							nvm_err '--reinstall-packages-from may not be provided more than once'
							return 6
						fi
						PROVIDED_REINSTALL_PACKAGES_FROM="$(nvm_echo "$1" | command cut -c 27-)" 
						if [ -z "${PROVIDED_REINSTALL_PACKAGES_FROM}" ]
						then
							nvm_err 'If --reinstall-packages-from is provided, it must point to an installed version of node.'
							return 6
						fi
						REINSTALL_PACKAGES_FROM="$(nvm_version "${PROVIDED_REINSTALL_PACKAGES_FROM}")"  || : ;;
					(--copy-packages-from=*) if [ -n "${PROVIDED_REINSTALL_PACKAGES_FROM-}" ]
						then
							nvm_err '--reinstall-packages-from may not be provided more than once, or combined with `--copy-packages-from`'
							return 6
						fi
						PROVIDED_REINSTALL_PACKAGES_FROM="$(nvm_echo "$1" | command cut -c 22-)" 
						if [ -z "${PROVIDED_REINSTALL_PACKAGES_FROM}" ]
						then
							nvm_err 'If --copy-packages-from is provided, it must point to an installed version of node.'
							return 6
						fi
						REINSTALL_PACKAGES_FROM="$(nvm_version "${PROVIDED_REINSTALL_PACKAGES_FROM}")"  || : ;;
					(--reinstall-packages-from | --copy-packages-from) nvm_err "If ${1} is provided, it must point to an installed version of node using \`=\`."
						return 6 ;;
					(--skip-default-packages) SKIP_DEFAULT_PACKAGES=true  ;;
					(*) ADDITIONAL_PARAMETERS="${ADDITIONAL_PARAMETERS} $1"  ;;
				esac
				shift
			done
			if [ -n "${PROVIDED_REINSTALL_PACKAGES_FROM-}" ] && [ "$(nvm_ensure_version_prefix "${PROVIDED_REINSTALL_PACKAGES_FROM}")" = "${VERSION}" ]
			then
				nvm_err "You can't reinstall global packages from the same version of node you're installing."
				return 4
			elif [ "${REINSTALL_PACKAGES_FROM-}" = 'N/A' ]
			then
				nvm_err "If --reinstall-packages-from is provided, it must point to an installed version of node."
				return 5
			fi
			local FLAVOR
			if nvm_is_iojs_version "${VERSION}"
			then
				FLAVOR="$(nvm_iojs_prefix)" 
			else
				FLAVOR="$(nvm_node_prefix)" 
			fi
			EXIT_CODE=0 
			if nvm_is_version_installed "${VERSION}"
			then
				nvm_err "${VERSION} is already installed."
				nvm use "${VERSION}"
				EXIT_CODE=$? 
				if [ $EXIT_CODE -eq 0 ]
				then
					if [ "${NVM_UPGRADE_NPM}" = 1 ]
					then
						nvm install-latest-npm
						EXIT_CODE=$? 
					fi
					if [ $EXIT_CODE -eq 0 ] && [ -z "${SKIP_DEFAULT_PACKAGES-}" ]
					then
						nvm_install_default_packages
					fi
					if [ $EXIT_CODE -eq 0 ] && [ -n "${REINSTALL_PACKAGES_FROM-}" ] && [ "_${REINSTALL_PACKAGES_FROM}" != "_N/A" ]
					then
						nvm reinstall-packages "${REINSTALL_PACKAGES_FROM}"
						EXIT_CODE=$? 
					fi
				fi
				if [ -n "${LTS-}" ]
				then
					LTS="$(echo "${LTS}" | tr '[:upper:]' '[:lower:]')" 
					nvm_ensure_default_set "lts/${LTS}"
				else
					nvm_ensure_default_set "${provided_version}"
				fi
				if [ $NVM_WRITE_TO_NVMRC -eq 1 ]
				then
					nvm_write_nvmrc "${VERSION}"
					EXIT_CODE=$? 
				fi
				if [ $EXIT_CODE -eq 0 ] && [ -n "${ALIAS-}" ]
				then
					nvm alias "${ALIAS}" "${provided_version}"
					EXIT_CODE=$? 
				fi
				return $EXIT_CODE
			fi
			if [ -n "${NVM_INSTALL_THIRD_PARTY_HOOK-}" ]
			then
				nvm_err '** $NVM_INSTALL_THIRD_PARTY_HOOK env var set; dispatching to third-party installation method **'
				local NVM_METHOD_PREFERENCE
				NVM_METHOD_PREFERENCE='binary' 
				if [ $nobinary -eq 1 ]
				then
					NVM_METHOD_PREFERENCE='source' 
				fi
				local VERSION_PATH
				VERSION_PATH="$(nvm_version_path "${VERSION}")" 
				"${NVM_INSTALL_THIRD_PARTY_HOOK}" "${VERSION}" "${FLAVOR}" std "${NVM_METHOD_PREFERENCE}" "${VERSION_PATH}" || {
					EXIT_CODE=$? 
					nvm_err '*** Third-party $NVM_INSTALL_THIRD_PARTY_HOOK env var failed to install! ***'
					return $EXIT_CODE
				}
				if ! nvm_is_version_installed "${VERSION}"
				then
					nvm_err '*** Third-party $NVM_INSTALL_THIRD_PARTY_HOOK env var claimed to succeed, but failed to install! ***'
					return 33
				fi
				EXIT_CODE=0 
			else
				if [ "_${NVM_OS}" = "_freebsd" ]
				then
					nobinary=1 
					nvm_err "Currently, there is no binary for FreeBSD"
				elif [ "_$NVM_OS" = "_openbsd" ]
				then
					nobinary=1 
					nvm_err "Currently, there is no binary for OpenBSD"
				elif [ "_${NVM_OS}" = "_sunos" ]
				then
					if ! nvm_has_solaris_binary "${VERSION}"
					then
						nobinary=1 
						nvm_err "Currently, there is no binary of version ${VERSION} for SunOS"
					fi
				fi
				if [ $nobinary -ne 1 ] && nvm_binary_available "${VERSION}"
				then
					NVM_NO_PROGRESS="${NVM_NO_PROGRESS:-${noprogress}}" NVM_OFFLINE="${NVM_OFFLINE}" nvm_install_binary "${FLAVOR}" std "${VERSION}" "${nosource}"
					EXIT_CODE=$? 
				else
					EXIT_CODE=-1 
					if [ $nosource -eq 1 ]
					then
						nvm_err "Binary download is not available for ${VERSION}"
						EXIT_CODE=3 
					fi
				fi
				if [ $EXIT_CODE -ne 0 ] && [ $nosource -ne 1 ]
				then
					if [ -z "${NVM_MAKE_JOBS-}" ]
					then
						nvm_get_make_jobs
					fi
					if [ "_${NVM_OS}" = "_win" ]
					then
						nvm_err 'Installing from source on non-WSL Windows is not supported'
						EXIT_CODE=87 
					else
						NVM_NO_PROGRESS="${NVM_NO_PROGRESS:-${noprogress}}" NVM_OFFLINE="${NVM_OFFLINE}" nvm_install_source "${FLAVOR}" std "${VERSION}" "${NVM_MAKE_JOBS}" "${ADDITIONAL_PARAMETERS}"
						EXIT_CODE=$? 
					fi
				fi
			fi
			if [ $EXIT_CODE -eq 0 ]
			then
				if nvm_use_if_needed "${VERSION}" && nvm_install_npm_if_needed "${VERSION}"
				then
					if [ -n "${LTS-}" ]
					then
						nvm_ensure_default_set "lts/${LTS}"
					else
						nvm_ensure_default_set "${provided_version}"
					fi
					if [ "${NVM_UPGRADE_NPM}" = 1 ]
					then
						nvm install-latest-npm
						EXIT_CODE=$? 
					fi
					if [ $EXIT_CODE -eq 0 ] && [ -z "${SKIP_DEFAULT_PACKAGES-}" ]
					then
						nvm_install_default_packages
					fi
					if [ $EXIT_CODE -eq 0 ] && [ -n "${REINSTALL_PACKAGES_FROM-}" ] && [ "_${REINSTALL_PACKAGES_FROM}" != "_N/A" ]
					then
						nvm reinstall-packages "${REINSTALL_PACKAGES_FROM}"
						EXIT_CODE=$? 
					fi
				else
					EXIT_CODE=$? 
				fi
			fi
			return $EXIT_CODE ;;
		("uninstall") if [ $# -ne 1 ]
			then
				nvm_err 'Usage: nvm uninstall <version>'
				nvm_err '       nvm uninstall --lts'
				nvm_err '       nvm uninstall --lts=<LTS name>'
				nvm_err '  Run `nvm --help` for full help.'
				return 127
			fi
			local PATTERN
			PATTERN="${1-}" 
			case "${PATTERN-}" in
				(--)  ;;
				(--lts | 'lts/*') VERSION="$(nvm_match_version "lts/*")"  ;;
				(lts/*) VERSION="$(nvm_match_version "lts/${PATTERN##lts/}")"  ;;
				(--lts=*) VERSION="$(nvm_match_version "lts/${PATTERN##--lts=}")"  ;;
				(*) VERSION="$(nvm_version "${PATTERN}")"  ;;
			esac
			if [ "_${VERSION}" = "_$(nvm_ls_current)" ]
			then
				if nvm_is_iojs_version "${VERSION}"
				then
					nvm_err "nvm: Cannot uninstall currently-active io.js version, ${VERSION} (inferred from ${PATTERN})."
				else
					nvm_err "nvm: Cannot uninstall currently-active node version, ${VERSION} (inferred from ${PATTERN})."
				fi
				return 1
			fi
			if ! nvm_is_version_installed "${VERSION}"
			then
				local REQUESTED_VERSION
				REQUESTED_VERSION="${PATTERN}" 
				if [ "_${VERSION}" != "_N/A" ] && [ "_${VERSION}" != "_${PATTERN}" ]
				then
					nvm_err "Version '${VERSION}' (inferred from ${PATTERN}) is not installed."
				else
					nvm_err "Version '${REQUESTED_VERSION}' is not installed."
				fi
				return
			fi
			local SLUG_BINARY
			local SLUG_SOURCE
			if nvm_is_iojs_version "${VERSION}"
			then
				SLUG_BINARY="$(nvm_get_download_slug iojs binary std "${VERSION}")" 
				SLUG_SOURCE="$(nvm_get_download_slug iojs source std "${VERSION}")" 
			else
				SLUG_BINARY="$(nvm_get_download_slug node binary std "${VERSION}")" 
				SLUG_SOURCE="$(nvm_get_download_slug node source std "${VERSION}")" 
			fi
			local NVM_SUCCESS_MSG
			if nvm_is_iojs_version "${VERSION}"
			then
				NVM_SUCCESS_MSG="Uninstalled io.js $(nvm_strip_iojs_prefix "${VERSION}")" 
			else
				NVM_SUCCESS_MSG="Uninstalled node ${VERSION}" 
			fi
			local VERSION_PATH
			VERSION_PATH="$(nvm_version_path "${VERSION}")" 
			if ! nvm_check_file_permissions "${VERSION_PATH}"
			then
				nvm_err 'Cannot uninstall, incorrect permissions on installation folder.'
				nvm_err 'This is usually caused by running `npm install -g` as root. Run the following commands as root to fix the permissions and then try again.'
				nvm_err
				nvm_err "  chown -R $(whoami) \"$(nvm_sanitize_path "${VERSION_PATH}")\""
				nvm_err "  chmod -R u+w \"$(nvm_sanitize_path "${VERSION_PATH}")\""
				return 1
			fi
			local CACHE_DIR
			CACHE_DIR="$(nvm_cache_dir)" 
			command rm -rf "${CACHE_DIR}/bin/${SLUG_BINARY}/files" "${CACHE_DIR}/src/${SLUG_SOURCE}/files" "${VERSION_PATH}" 2> /dev/null
			nvm_echo "${NVM_SUCCESS_MSG}"
			for ALIAS in $(nvm_grep -l "${VERSION}" "$(nvm_alias_path)"/* 2>/dev/null)
			do
				nvm unalias "$(command basename "${ALIAS}")"
			done ;;
		("deactivate") local NVM_SILENT
			while [ $# -ne 0 ]
			do
				case "${1}" in
					(--silent) NVM_SILENT=1  ;;
					(--)  ;;
				esac
				shift
			done
			local NEWPATH
			NEWPATH="$(nvm_strip_path "${PATH}" "/bin")" 
			if [ "_${PATH}" = "_${NEWPATH}" ]
			then
				if [ "${NVM_SILENT:-0}" -ne 1 ]
				then
					nvm_err "Could not find ${NVM_DIR}/*/bin in \${PATH}"
				fi
			else
				export PATH="${NEWPATH}" 
				\hash -r
				if [ "${NVM_SILENT:-0}" -ne 1 ]
				then
					nvm_echo "${NVM_DIR}/*/bin removed from \${PATH}"
				fi
			fi
			if [ -n "${MANPATH-}" ]
			then
				NEWPATH="$(nvm_strip_path "${MANPATH}" "/share/man")" 
				if [ "_${MANPATH}" = "_${NEWPATH}" ]
				then
					if [ "${NVM_SILENT:-0}" -ne 1 ]
					then
						nvm_err "Could not find ${NVM_DIR}/*/share/man in \${MANPATH}"
					fi
				else
					export MANPATH="${NEWPATH}" 
					if [ "${NVM_SILENT:-0}" -ne 1 ]
					then
						nvm_echo "${NVM_DIR}/*/share/man removed from \${MANPATH}"
					fi
				fi
			fi
			if [ -n "${NODE_PATH-}" ]
			then
				NEWPATH="$(nvm_strip_path "${NODE_PATH}" "/lib/node_modules")" 
				if [ "_${NODE_PATH}" != "_${NEWPATH}" ]
				then
					export NODE_PATH="${NEWPATH}" 
					if [ "${NVM_SILENT:-0}" -ne 1 ]
					then
						nvm_echo "${NVM_DIR}/*/lib/node_modules removed from \${NODE_PATH}"
					fi
				fi
			fi
			unset NVM_BIN
			unset NVM_INC ;;
		("use") local PROVIDED_VERSION
			local NVM_SILENT
			local NVM_SILENT_ARG
			local NVM_DELETE_PREFIX
			NVM_DELETE_PREFIX=0 
			local NVM_LTS
			local IS_VERSION_FROM_NVMRC
			IS_VERSION_FROM_NVMRC=0 
			local NVM_WRITE_TO_NVMRC
			NVM_WRITE_TO_NVMRC=0 
			while [ $# -ne 0 ]
			do
				case "$1" in
					(--silent) NVM_SILENT=1 
						NVM_SILENT_ARG='--silent'  ;;
					(--delete-prefix) NVM_DELETE_PREFIX=1  ;;
					(--)  ;;
					(--lts) NVM_LTS='*'  ;;
					(--lts=*) NVM_LTS="${1##--lts=}"  ;;
					(--save | -w) if [ $NVM_WRITE_TO_NVMRC -eq 1 ]
						then
							nvm_err '--save and -w may only be provided once'
							return 6
						fi
						NVM_WRITE_TO_NVMRC=1  ;;
					(--*)  ;;
					(*) if [ -n "${1-}" ]
						then
							PROVIDED_VERSION="$1" 
						fi ;;
				esac
				shift
			done
			if [ -n "${NVM_LTS-}" ]
			then
				VERSION="$(nvm_match_version "lts/${NVM_LTS:-*}")" 
			elif [ -z "${PROVIDED_VERSION-}" ]
			then
				{
					PROVIDED_VERSION="$(NVM_SILENT="${NVM_SILENT:-0}" nvm_rc_version 3>&1 1>&4)" 
				} 4>&1
				if [ -n "${PROVIDED_VERSION}" ]
				then
					IS_VERSION_FROM_NVMRC=1 
					VERSION="$(nvm_version "${PROVIDED_VERSION}")" 
				fi
				if [ -z "${VERSION}" ]
				then
					nvm_err 'Please see `nvm --help` or https://github.com/nvm-sh/nvm#nvmrc for more information.'
					return 127
				fi
			else
				VERSION="$(nvm_match_version "${PROVIDED_VERSION}")" 
			fi
			if [ -z "${VERSION}" ]
			then
				nvm_err 'Usage: nvm use [<version>]'
				nvm_err '  Provide a <version>, or run from a directory containing an .nvmrc file.'
				nvm_err '  Run `nvm --help` for full help.'
				return 127
			fi
			if [ $NVM_WRITE_TO_NVMRC -eq 1 ]
			then
				nvm_write_nvmrc "${VERSION}"
			fi
			if [ "_${VERSION}" = '_system' ]
			then
				if nvm_has_system_node && nvm deactivate "${NVM_SILENT_ARG-}" > /dev/null 2>&1
				then
					if [ "${NVM_SILENT:-0}" -ne 1 ]
					then
						nvm_echo "Now using system version of node: $(node -v 2>/dev/null)$(nvm_print_npm_version)"
					fi
					return
				elif nvm_has_system_iojs && nvm deactivate "${NVM_SILENT_ARG-}" > /dev/null 2>&1
				then
					if [ "${NVM_SILENT:-0}" -ne 1 ]
					then
						nvm_echo "Now using system version of io.js: $(iojs --version 2>/dev/null)$(nvm_print_npm_version)"
					fi
					return
				elif [ "${NVM_SILENT:-0}" -ne 1 ]
				then
					nvm_err 'System version of node not found.'
				fi
				return 127
			elif [ "_${VERSION}" = '_∞' ]
			then
				if [ "${NVM_SILENT:-0}" -ne 1 ]
				then
					nvm_err "The alias \"${PROVIDED_VERSION}\" leads to an infinite loop. Aborting."
				fi
				return 8
			fi
			if [ "${VERSION}" = 'N/A' ]
			then
				if [ "${NVM_SILENT:-0}" -ne 1 ]
				then
					nvm_ensure_version_installed "${PROVIDED_VERSION}" "${IS_VERSION_FROM_NVMRC}"
				fi
				return 3
			elif ! nvm_ensure_version_installed "${VERSION}" "${IS_VERSION_FROM_NVMRC}"
			then
				return $?
			fi
			local NVM_VERSION_DIR
			NVM_VERSION_DIR="$(nvm_version_path "${VERSION}")" 
			PATH="$(nvm_change_path "${PATH}" "/bin" "${NVM_VERSION_DIR}")" 
			if nvm_has manpath
			then
				if [ -z "${MANPATH-}" ]
				then
					local MANPATH
					MANPATH=$(manpath) 
				fi
				MANPATH="$(nvm_change_path "${MANPATH}" "/share/man" "${NVM_VERSION_DIR}")" 
				export MANPATH
			fi
			export PATH
			\hash -r
			export NVM_BIN="${NVM_VERSION_DIR}/bin" 
			export NVM_INC="${NVM_VERSION_DIR}/include/node" 
			if [ "${NVM_SYMLINK_CURRENT-}" = true ]
			then
				command rm -f "${NVM_DIR}/current" && ln -s "${NVM_VERSION_DIR}" "${NVM_DIR}/current"
			fi
			local NVM_USE_OUTPUT
			NVM_USE_OUTPUT='' 
			if [ "${NVM_SILENT:-0}" -ne 1 ]
			then
				if nvm_is_iojs_version "${VERSION}"
				then
					NVM_USE_OUTPUT="Now using io.js $(nvm_strip_iojs_prefix "${VERSION}")$(nvm_print_npm_version)" 
				else
					NVM_USE_OUTPUT="Now using node ${VERSION}$(nvm_print_npm_version)" 
				fi
			fi
			if [ "_${VERSION}" != "_system" ]
			then
				local NVM_USE_CMD
				NVM_USE_CMD="nvm use --delete-prefix" 
				if [ -n "${PROVIDED_VERSION}" ]
				then
					NVM_USE_CMD="${NVM_USE_CMD} ${VERSION}" 
				fi
				if [ "${NVM_SILENT:-0}" -eq 1 ]
				then
					NVM_USE_CMD="${NVM_USE_CMD} --silent" 
				fi
				if ! nvm_die_on_prefix "${NVM_DELETE_PREFIX}" "${NVM_USE_CMD}" "${NVM_VERSION_DIR}"
				then
					return 11
				fi
			fi
			if [ -n "${NVM_USE_OUTPUT-}" ] && [ "${NVM_SILENT:-0}" -ne 1 ]
			then
				nvm_echo "${NVM_USE_OUTPUT}"
			fi ;;
		("run") local provided_version
			local has_checked_nvmrc
			has_checked_nvmrc=0 
			local IS_VERSION_FROM_NVMRC
			IS_VERSION_FROM_NVMRC=0 
			local NVM_SILENT
			local NVM_SILENT_ARG
			local NVM_LTS
			while [ $# -gt 0 ]
			do
				case "$1" in
					(--silent) NVM_SILENT=1 
						NVM_SILENT_ARG='--silent' 
						shift ;;
					(--lts) NVM_LTS='*' 
						shift ;;
					(--lts=*) NVM_LTS="${1##--lts=}" 
						shift ;;
					(*) if [ -n "$1" ]
						then
							break
						else
							shift
						fi ;;
				esac
			done
			if [ $# -lt 1 ] && [ -z "${NVM_LTS-}" ]
			then
				local NVM_RC_VERSION
				{
					NVM_RC_VERSION="$(NVM_SILENT="${NVM_SILENT:-0}" nvm_rc_version 3>&1 1>&4)" 
				} 4>&1 && has_checked_nvmrc=1 
				if [ -n "${NVM_RC_VERSION}" ]
				then
					VERSION="$(nvm_version "${NVM_RC_VERSION}")"  || :
				fi
				if [ "${VERSION:-N/A}" = 'N/A' ]
				then
					nvm_err 'Usage: nvm run [<version>] [<args>]'
					nvm_err '  Provide a <version>, or run from a directory containing an .nvmrc file.'
					nvm_err '  Run `nvm --help` for full help.'
					return 127
				fi
			fi
			if [ -z "${NVM_LTS-}" ]
			then
				provided_version="$1" 
				if [ -n "${provided_version}" ]
				then
					VERSION="$(nvm_version "${provided_version}")"  || :
					if [ "_${VERSION:-N/A}" = '_N/A' ] && ! nvm_is_valid_version "${provided_version}"
					then
						provided_version='' 
						if [ $has_checked_nvmrc -ne 1 ]
						then
							{
								NVM_RC_VERSION="$(NVM_SILENT="${NVM_SILENT:-0}" nvm_rc_version 3>&1 1>&4)" 
							} 4>&1 && has_checked_nvmrc=1 
						fi
						if [ -z "${NVM_RC_VERSION-}" ]
						then
							if [ "${NVM_SILENT:-0}" -ne 1 ]
							then
								nvm_err 'WARNING: `nvm run` was invoked without a version argument and without an .nvmrc file.'
								nvm_err '  Falling back to the active node version; this will become an error in a future release.'
								nvm_err '  Pass `current` explicitly (e.g. `nvm run current ...`) to silence this warning.'
							fi
							NVM_RC_VERSION="$(nvm_version current)"  || :
						fi
						provided_version="${NVM_RC_VERSION}" 
						IS_VERSION_FROM_NVMRC=1 
						VERSION="$(nvm_version "${NVM_RC_VERSION}")"  || :
					else
						shift
					fi
				fi
			fi
			local NVM_IOJS
			if nvm_is_iojs_version "${VERSION}"
			then
				NVM_IOJS=true 
			fi
			local EXIT_CODE
			nvm_is_zsh && setopt local_options shwordsplit
			local LTS_ARG
			if [ -n "${NVM_LTS-}" ]
			then
				LTS_ARG="--lts=${NVM_LTS-}" 
				VERSION='' 
			fi
			if [ "_${VERSION}" = "_N/A" ]
			then
				nvm_ensure_version_installed "${provided_version}" "${IS_VERSION_FROM_NVMRC}"
			elif [ "${NVM_IOJS}" = true ]
			then
				nvm exec "${NVM_SILENT_ARG-}" "${LTS_ARG-}" "${VERSION}" iojs "$@"
			else
				nvm exec "${NVM_SILENT_ARG-}" "${LTS_ARG-}" "${VERSION}" node "$@"
			fi
			EXIT_CODE="$?" 
			return $EXIT_CODE ;;
		("exec") local NVM_SILENT
			local NVM_LTS
			while [ $# -gt 0 ]
			do
				case "$1" in
					(--silent) NVM_SILENT=1 
						shift ;;
					(--lts) NVM_LTS='*' 
						shift ;;
					(--lts=*) NVM_LTS="${1##--lts=}" 
						shift ;;
					(--) break ;;
					(--*) nvm_err "Unsupported option \"$1\"."
						return 55 ;;
					(*) if [ -n "$1" ]
						then
							break
						else
							shift
						fi ;;
				esac
			done
			local provided_version
			provided_version="$1" 
			local VERSION_SOURCE
			VERSION_SOURCE='' 
			if [ "${NVM_LTS-}" != '' ]
			then
				provided_version="lts/${NVM_LTS:-*}" 
				VERSION="${provided_version}" 
				VERSION_SOURCE='lts' 
			elif [ -n "${provided_version}" ]
			then
				VERSION="$(nvm_version "${provided_version}")"  || :
				if [ "_${VERSION}" = '_N/A' ] && ! nvm_is_valid_version "${provided_version}"
				then
					{
						provided_version="$(NVM_SILENT="${NVM_SILENT:-0}" nvm_rc_version 3>&1 1>&4)" 
					} 4>&1 && has_checked_nvmrc=1 
					VERSION="$(nvm_version "${provided_version}")"  || :
					if [ -n "${provided_version}" ]
					then
						VERSION_SOURCE='nvmrc' 
					fi
				else
					VERSION_SOURCE='arg' 
					shift
				fi
			fi
			if [ -z "${VERSION_SOURCE}" ]
			then
				if [ "${NVM_SILENT:-0}" -ne 1 ]
				then
					nvm_err 'WARNING: `nvm exec` was invoked without a version argument and without an .nvmrc file.'
					nvm_err '  Falling back to the active node version; this will become an error in a future release.'
					nvm_err '  Pass `current` explicitly (e.g. `nvm exec current ...`) to silence this warning.'
				fi
				provided_version='current' 
				VERSION="$(nvm_version current)"  || :
			fi
			nvm_ensure_version_installed "${provided_version}"
			EXIT_CODE=$? 
			if [ "${EXIT_CODE}" != "0" ]
			then
				return $EXIT_CODE
			fi
			if [ "${NVM_SILENT:-0}" -ne 1 ]
			then
				if [ "${NVM_LTS-}" = '*' ]
				then
					nvm_echo "Running node latest LTS -> $(nvm_version "${VERSION}")$(nvm use --silent "${VERSION}" && nvm_print_npm_version)"
				elif [ -n "${NVM_LTS-}" ]
				then
					nvm_echo "Running node LTS \"${NVM_LTS-}\" -> $(nvm_version "${VERSION}")$(nvm use --silent "${VERSION}" && nvm_print_npm_version)"
				elif nvm_is_iojs_version "${VERSION}"
				then
					nvm_echo "Running io.js $(nvm_strip_iojs_prefix "${VERSION}")$(nvm use --silent "${VERSION}" && nvm_print_npm_version)"
				else
					nvm_echo "Running node ${VERSION}$(nvm use --silent "${VERSION}" && nvm_print_npm_version)"
				fi
			fi
			NODE_VERSION="${VERSION}" "${NVM_DIR}/nvm-exec" "$@" ;;
		("ls" | "list") local PATTERN
			local NVM_NO_COLORS
			local NVM_NO_ALIAS
			while [ $# -gt 0 ]
			do
				case "${1}" in
					(--)  ;;
					(--no-colors) NVM_NO_COLORS="${1}"  ;;
					(--no-alias) NVM_NO_ALIAS="${1}"  ;;
					(--*) nvm_err "Unsupported option \"${1}\"."
						return 55 ;;
					(*) PATTERN="${PATTERN:-$1}"  ;;
				esac
				shift
			done
			if [ -n "${PATTERN-}" ] && [ -n "${NVM_NO_ALIAS-}" ]
			then
				nvm_err '`--no-alias` is not supported when a pattern is provided.'
				return 55
			fi
			local NVM_LS_OUTPUT
			local NVM_LS_EXIT_CODE
			NVM_LS_OUTPUT=$(nvm_ls "${PATTERN-}") 
			NVM_LS_EXIT_CODE=$? 
			NVM_NO_COLORS="${NVM_NO_COLORS-}" nvm_print_versions "${NVM_LS_OUTPUT}"
			if [ -z "${NVM_NO_ALIAS-}" ] && [ -z "${PATTERN-}" ]
			then
				if [ -n "${NVM_NO_COLORS-}" ]
				then
					nvm alias --no-colors
				else
					nvm alias
				fi
			fi
			return $NVM_LS_EXIT_CODE ;;
		("ls-remote" | "list-remote") local NVM_LTS
			local PATTERN
			local NVM_NO_COLORS
			while [ $# -gt 0 ]
			do
				case "${1-}" in
					(--)  ;;
					(--lts) NVM_LTS='*'  ;;
					(--lts=*) NVM_LTS="${1##--lts=}"  ;;
					(--no-colors) NVM_NO_COLORS="${1}"  ;;
					(--*) nvm_err "Unsupported option \"${1}\"."
						return 55 ;;
					(*) if [ -z "${PATTERN-}" ]
						then
							PATTERN="${1-}" 
							if [ -z "${NVM_LTS-}" ]
							then
								case "${PATTERN}" in
									('lts/*') NVM_LTS='*' 
										PATTERN=''  ;;
									(lts/*) NVM_LTS="${PATTERN##lts/}" 
										PATTERN=''  ;;
								esac
							fi
						fi ;;
				esac
				shift
			done
			local NVM_OUTPUT
			local EXIT_CODE
			NVM_OUTPUT="$(NVM_LTS="${NVM_LTS-}" nvm_remote_versions "${PATTERN-}" &&:)" 
			EXIT_CODE=$? 
			if [ -n "${NVM_OUTPUT}" ]
			then
				NVM_NO_COLORS="${NVM_NO_COLORS-}" nvm_print_versions "${NVM_OUTPUT}"
				return $EXIT_CODE
			fi
			NVM_NO_COLORS="${NVM_NO_COLORS-}" nvm_print_versions "N/A"
			return 3 ;;
		("current") nvm_version current ;;
		("which") local NVM_SILENT
			local provided_version
			while [ $# -ne 0 ]
			do
				case "${1}" in
					(--silent) NVM_SILENT=1  ;;
					(--)  ;;
					(*) provided_version="${1-}"  ;;
				esac
				shift
			done
			if [ -z "${provided_version-}" ]
			then
				{
					provided_version="$(NVM_SILENT="${NVM_SILENT:-0}" nvm_rc_version 3>&1 1>&4)" 
				} 4>&1
				if [ -n "${provided_version}" ]
				then
					VERSION=$(nvm_version "${provided_version}")  || :
				fi
			elif [ "${provided_version}" != 'system' ]
			then
				VERSION="$(nvm_version "${provided_version}")"  || :
			else
				VERSION="${provided_version-}" 
			fi
			if [ -z "${VERSION}" ]
			then
				nvm_err 'Usage: nvm which [current | <version>]'
				nvm_err '  Provide a <version>, or run from a directory containing an .nvmrc file.'
				nvm_err '  Run `nvm --help` for full help.'
				return 127
			fi
			if [ "_${VERSION}" = '_system' ]
			then
				if nvm_has_system_iojs > /dev/null 2>&1 || nvm_has_system_node > /dev/null 2>&1
				then
					local NVM_BIN
					NVM_BIN="$(nvm use system >/dev/null 2>&1 && command which node)" 
					if [ -n "${NVM_BIN}" ]
					then
						nvm_echo "${NVM_BIN}"
						return
					fi
					return 1
				fi
				nvm_err 'System version of node not found.'
				return 127
			elif [ "${VERSION}" = '∞' ]
			then
				nvm_err "The alias \"${provided_version}\" leads to an infinite loop. Aborting."
				return 8
			fi
			nvm_ensure_version_installed "${provided_version}"
			EXIT_CODE=$? 
			if [ "${EXIT_CODE}" != "0" ]
			then
				return $EXIT_CODE
			fi
			local NVM_VERSION_DIR
			NVM_VERSION_DIR="$(nvm_version_path "${VERSION}")" 
			nvm_echo "${NVM_VERSION_DIR}/bin/node" ;;
		("alias") local NVM_ALIAS_DIR
			NVM_ALIAS_DIR="$(nvm_alias_path)" 
			local NVM_CURRENT
			NVM_CURRENT="$(nvm_ls_current)" 
			command mkdir -p "${NVM_ALIAS_DIR}/lts"
			local ALIAS
			local TARGET
			local NVM_NO_COLORS
			ALIAS='--' 
			TARGET='--' 
			while [ $# -gt 0 ]
			do
				case "${1-}" in
					(--)  ;;
					(--no-colors) NVM_NO_COLORS="${1}"  ;;
					(--*) nvm_err "Unsupported option \"${1}\"."
						return 55 ;;
					(*) if [ "${ALIAS}" = '--' ]
						then
							ALIAS="${1-}" 
						elif [ "${TARGET}" = '--' ]
						then
							TARGET="${1-}" 
						fi ;;
				esac
				shift
			done
			if [ -z "${TARGET}" ]
			then
				nvm unalias "${ALIAS}"
				return $?
			elif echo "${ALIAS}" | grep -q "#"
			then
				nvm_err 'Aliases with a comment delimiter (#) are not supported.'
				return 1
			elif [ "${TARGET}" != '--' ]
			then
				if [ "${ALIAS#*\/}" != "${ALIAS}" ]
				then
					nvm_err 'Aliases in subdirectories are not supported.'
					return 1
				fi
				VERSION="$(nvm_version "${TARGET}")"  || :
				if [ "${VERSION}" = 'N/A' ]
				then
					nvm_err "! WARNING: Version '${TARGET}' does not exist."
				fi
				nvm_make_alias "${ALIAS}" "${TARGET}"
				NVM_NO_COLORS="${NVM_NO_COLORS-}" NVM_CURRENT="${NVM_CURRENT-}" DEFAULT=false nvm_print_formatted_alias "${ALIAS}" "${TARGET}" "${VERSION}"
			else
				if [ "${ALIAS-}" = '--' ]
				then
					unset ALIAS
				fi
				nvm_list_aliases "${ALIAS-}"
			fi ;;
		("unalias") local NVM_ALIAS_DIR
			NVM_ALIAS_DIR="$(nvm_alias_path)" 
			command mkdir -p "${NVM_ALIAS_DIR}"
			if [ $# -ne 1 ]
			then
				nvm_err 'Usage: nvm unalias <name>'
				nvm_err '  Run `nvm --help` for full help.'
				return 127
			fi
			if [ "${1#*\/}" != "${1-}" ]
			then
				nvm_err 'Aliases in subdirectories are not supported.'
				return 1
			fi
			local NVM_IOJS_PREFIX
			local NVM_NODE_PREFIX
			NVM_IOJS_PREFIX="$(nvm_iojs_prefix)" 
			NVM_NODE_PREFIX="$(nvm_node_prefix)" 
			local NVM_ALIAS_EXISTS
			NVM_ALIAS_EXISTS=0 
			if [ -f "${NVM_ALIAS_DIR}/${1-}" ]
			then
				NVM_ALIAS_EXISTS=1 
			fi
			if [ $NVM_ALIAS_EXISTS -eq 0 ]
			then
				case "$1" in
					("stable" | "unstable" | "${NVM_IOJS_PREFIX}" | "${NVM_NODE_PREFIX}" | "system") nvm_err "${1-} is a default (built-in) alias and cannot be deleted."
						return 1 ;;
				esac
				nvm_err "Alias ${1-} doesn't exist!"
				return
			fi
			local NVM_ALIAS_ORIGINAL
			NVM_ALIAS_ORIGINAL="$(nvm_alias "${1}")" 
			command rm -f "${NVM_ALIAS_DIR}/${1}"
			nvm_echo "Deleted alias ${1} - restore it with \`nvm alias \"${1}\" \"${NVM_ALIAS_ORIGINAL}\"\`" ;;
		("install-latest-npm") if [ $# -ne 0 ]
			then
				nvm_err 'Usage: nvm install-latest-npm'
				nvm_err '  Run `nvm --help` for full help.'
				return 127
			fi
			nvm_install_latest_npm ;;
		("reinstall-packages" | "copy-packages") if [ $# -ne 1 ]
			then
				nvm_err "Usage: nvm ${COMMAND} <version>"
				nvm_err '  Run `nvm --help` for full help.'
				return 127
			fi
			local PROVIDED_VERSION
			PROVIDED_VERSION="${1-}" 
			if [ "${PROVIDED_VERSION}" = "$(nvm_ls_current)" ] || [ "$(nvm_version "${PROVIDED_VERSION}" ||:)" = "$(nvm_ls_current)" ]
			then
				nvm_err 'Can not reinstall packages from the current version of node.'
				return 2
			fi
			local VERSION
			if [ "_${PROVIDED_VERSION}" = "_system" ]
			then
				if ! nvm_has_system_node && ! nvm_has_system_iojs
				then
					nvm_err 'No system version of node or io.js detected.'
					return 3
				fi
				VERSION="system" 
			else
				VERSION="$(nvm_version "${PROVIDED_VERSION}")"  || :
			fi
			local NPMLIST
			NPMLIST="$(nvm_npm_global_modules "${VERSION}")" 
			local INSTALLS
			local LINKS
			INSTALLS="${NPMLIST%% //// *}" 
			LINKS="${NPMLIST##* //// }" 
			nvm_echo "Reinstalling global packages from ${VERSION}..."
			if [ -n "${INSTALLS}" ]
			then
				nvm_echo "${INSTALLS}" | command xargs npm install -g --quiet
			else
				nvm_echo "No installed global packages found..."
			fi
			nvm_echo "Linking global packages from ${VERSION}..."
			if [ -n "${LINKS}" ]
			then
				(
					set -f
					IFS='
' 
					for LINK in ${LINKS}
					do
						set +f
						unset IFS
						if [ -n "${LINK}" ]
						then
							case "${LINK}" in
								('/'*) (
										nvm_cd "${LINK}" && npm link
									) ;;
								(*) (
										nvm_cd "$(npm root -g)/../${LINK}" && npm link
									) ;;
							esac
						fi
					done
				)
			else
				nvm_echo "No linked global packages found..."
			fi ;;
		("clear-cache") command rm -f "${NVM_DIR}/v*" "$(nvm_version_dir)" 2> /dev/null
			nvm_echo 'nvm cache cleared.' ;;
		("version") nvm_version "${1}" ;;
		("version-remote") local NVM_LTS
			local PATTERN
			while [ $# -gt 0 ]
			do
				case "${1-}" in
					(--)  ;;
					(--lts) NVM_LTS='*'  ;;
					(--lts=*) NVM_LTS="${1##--lts=}"  ;;
					(--*) nvm_err "Unsupported option \"${1}\"."
						return 55 ;;
					(*) PATTERN="${PATTERN:-${1}}"  ;;
				esac
				shift
			done
			case "${PATTERN-}" in
				('lts/*') NVM_LTS='*' 
					unset PATTERN ;;
				(lts/*) NVM_LTS="${PATTERN##lts/}" 
					unset PATTERN ;;
			esac
			NVM_VERSION_ONLY=true NVM_LTS="${NVM_LTS-}" nvm_remote_version "${PATTERN:-node}" ;;
		("--version" | "-v") nvm_echo '0.40.6' ;;
		("unload") nvm deactivate > /dev/null 2>&1
			unset -f nvm nvm_iojs_prefix nvm_node_prefix nvm_add_iojs_prefix nvm_strip_iojs_prefix nvm_is_iojs_version nvm_is_alias nvm_has_non_aliased nvm_ls_remote nvm_ls_remote_iojs nvm_ls_remote_index_tab nvm_ls nvm_remote_version nvm_remote_versions nvm_install_binary nvm_install_source nvm_clang_version nvm_get_mirror nvm_get_download_slug nvm_download_artifact nvm_install_npm_if_needed nvm_use_if_needed nvm_check_file_permissions nvm_print_versions nvm_compute_checksum nvm_get_checksum_binary nvm_get_checksum_alg nvm_get_checksum nvm_compare_checksum nvm_version nvm_rc_version nvm_match_version nvm_ensure_default_set nvm_get_arch nvm_get_os nvm_print_implicit_alias nvm_validate_implicit_alias nvm_resolve_alias nvm_ls_current nvm_alias nvm_binary_available nvm_change_path nvm_strip_path nvm_num_version_groups nvm_format_version nvm_ensure_version_prefix nvm_normalize_version nvm_is_valid_version nvm_normalize_lts nvm_ensure_version_installed nvm_cache_dir nvm_ls_cached nvm_offline_version nvm_version_path nvm_alias_path nvm_version_dir nvm_find_nvmrc nvm_find_up nvm_find_project_dir nvm_tree_contains_path nvm_version_greater nvm_version_greater_than_or_equal_to nvm_print_npm_version nvm_install_latest_npm nvm_npm_global_modules nvm_has_system_node nvm_has_system_iojs nvm_download nvm_get_latest nvm_has nvm_has_executable nvm_install_default_packages nvm_get_default_packages nvm_curl_use_compression nvm_curl_version nvm_auto nvm_supports_xz nvm_echo nvm_err nvm_grep nvm_cd nvm_die_on_prefix nvm_get_make_jobs nvm_get_minor_version nvm_has_solaris_binary nvm_is_merged_node_version nvm_is_natural_num nvm_is_version_installed nvm_list_aliases nvm_make_alias nvm_print_alias_path nvm_print_default_alias nvm_print_formatted_alias nvm_resolve_local_alias nvm_sanitize_path nvm_has_colors nvm_process_parameters nvm_node_version_has_solaris_binary nvm_iojs_version_has_solaris_binary nvm_curl_libz_support nvm_command_info nvm_is_zsh nvm_stdout_is_terminal nvm_npmrc_bad_news_bears nvm_sanitize_auth_header nvm_get_colors nvm_set_colors nvm_print_color_code nvm_wrap_with_color_code nvm_format_help_message_colors nvm_echo_with_colors nvm_err_with_colors nvm_get_artifact_compression nvm_install_binary_extract nvm_extract_tarball nvm_process_nvmrc nvm_process_nvmrc_content nvm_nvmrc_invalid_msg nvm_write_nvmrc > /dev/null 2>&1
			unset NVM_NODEJS_ORG_MIRROR NVM_IOJS_ORG_MIRROR NVM_DIR NVM_CD_FLAGS NVM_BIN NVM_INC NVM_MAKE_JOBS NVM_COLORS INSTALLED_COLOR SYSTEM_COLOR CURRENT_COLOR NOT_INSTALLED_COLOR DEFAULT_COLOR LTS_COLOR > /dev/null 2>&1 ;;
		("set-colors") local EXIT_CODE
			nvm_set_colors "${1-}"
			EXIT_CODE=$? 
			if [ "$EXIT_CODE" -eq 17 ]
			then
				nvm --help >&2
				nvm_echo
				nvm_err_with_colors "\033[1;37mPlease pass in five \033[1;31mvalid color codes\033[1;37m. Choose from: rRgGbBcCyYmMkKeW\033[0m"
			fi ;;
		(*) nvm --help >&2
			return 127 ;;
	esac
}
nvm_add_iojs_prefix () {
	nvm_echo "$(nvm_iojs_prefix)-$(nvm_ensure_version_prefix "$(nvm_strip_iojs_prefix "${1-}")")"
}
nvm_alias () {
	local ALIAS
	ALIAS="${1-}" 
	if [ -z "${ALIAS}" ]
	then
		nvm_err 'An alias is required.'
		return 1
	fi
	if ! ALIAS="$(nvm_normalize_lts "${ALIAS}")" 
	then
		return $?
	fi
	if [ -z "${ALIAS}" ]
	then
		return 2
	fi
	local NVM_ALIAS_PATH
	NVM_ALIAS_PATH="$(nvm_alias_path)/${ALIAS}" 
	if [ ! -f "${NVM_ALIAS_PATH}" ]
	then
		nvm_err 'Alias does not exist.'
		return 2
	fi
	if [ ! -r "${NVM_ALIAS_PATH}" ]
	then
		nvm_err "Alias file is not readable: ${NVM_ALIAS_PATH}"
		return 0
	fi
	local NVM_ALIAS_LINE
	while IFS= read -r NVM_ALIAS_LINE || [ -n "${NVM_ALIAS_LINE}" ]
	do
		NVM_ALIAS_LINE="${NVM_ALIAS_LINE%%#*}" 
		case "${NVM_ALIAS_LINE}" in
			(*[![:space:]]*)  ;;
			(*) continue ;;
		esac
		NVM_ALIAS_LINE="${NVM_ALIAS_LINE%"${NVM_ALIAS_LINE##*[![:space:]]}"}" 
		nvm_echo "${NVM_ALIAS_LINE}"
	done < "${NVM_ALIAS_PATH}"
}
nvm_alias_path () {
	nvm_echo "$(nvm_version_dir old)/alias"
}
nvm_auto () {
	local NVM_MODE
	NVM_MODE="${1-}" 
	case "${NVM_MODE}" in
		(none) return 0 ;;
		(use) local VERSION
			local NVM_CURRENT
			NVM_CURRENT="$(nvm_ls_current)" 
			if [ "_${NVM_CURRENT}" = '_none' ] || [ "_${NVM_CURRENT}" = '_system' ]
			then
				VERSION="$(nvm_resolve_local_alias default 2>/dev/null || nvm_echo)" 
				if [ -n "${VERSION}" ]
				then
					if [ "_${VERSION}" != '_N/A' ] && nvm_is_valid_version "${VERSION}"
					then
						nvm use --silent "${VERSION}" > /dev/null
					else
						return 0
					fi
				elif nvm_rc_version 3> /dev/null > /dev/null 2>&1
				then
					nvm use --silent > /dev/null
				fi
			else
				nvm use --silent "${NVM_CURRENT}" > /dev/null
			fi ;;
		(install) local VERSION
			VERSION="$(nvm_alias default 2>/dev/null || nvm_echo)" 
			if [ -n "${VERSION}" ] && [ "_${VERSION}" != '_N/A' ] && nvm_is_valid_version "${VERSION}"
			then
				nvm install "${VERSION}" > /dev/null
			elif nvm_rc_version 3> /dev/null > /dev/null 2>&1
			then
				nvm install > /dev/null
			else
				return 0
			fi ;;
		(*) nvm_err 'Invalid auto mode supplied.'
			return 1 ;;
	esac
}
nvm_binary_available () {
	nvm_version_greater_than_or_equal_to "$(nvm_strip_iojs_prefix "${1-}")" v0.8.6
}
nvm_cache_dir () {
	nvm_echo "${NVM_DIR}/.cache"
}
nvm_cd () {
	\cd "$@"
}
nvm_change_path () {
	if [ -z "${1-}" ]
	then
		nvm_echo "${3-}${2-}"
	elif ! nvm_echo "${1-}" | nvm_grep -q "${NVM_DIR}/[^/]*${2-}" && ! nvm_echo "${1-}" | nvm_grep -q "${NVM_DIR}/versions/[^/]*/[^/]*${2-}"
	then
		nvm_echo "${3-}${2-}:${1-}"
	elif nvm_echo "${1-}" | nvm_grep -Eq "(^|:)(/usr(/local)?)?${2-}:.*${NVM_DIR}/[^/]*${2-}" || nvm_echo "${1-}" | nvm_grep -Eq "(^|:)(/usr(/local)?)?${2-}:.*${NVM_DIR}/versions/[^/]*/[^/]*${2-}"
	then
		nvm_echo "${3-}${2-}:${1-}"
	else
		nvm_echo "${1-}" | command sed -e "s#${NVM_DIR}/[^/]*${2-}[^:]*#${3-}${2-}#" -e "s#${NVM_DIR}/versions/[^/]*/[^/]*${2-}[^:]*#${3-}${2-}#"
	fi
}
nvm_check_file_permissions () {
	nvm_is_zsh && setopt local_options nonomatch
	for FILE in "$1"/* "$1"/.[!.]* "$1"/..?*
	do
		if [ -d "$FILE" ]
		then
			if [ -n "${NVM_DEBUG-}" ]
			then
				nvm_err "${FILE}"
			fi
			if [ ! -L "${FILE}" ] && ! nvm_check_file_permissions "${FILE}"
			then
				return 2
			fi
		elif [ -e "$FILE" ] && [ ! -w "$FILE" ] && [ -z "$(command find "${FILE}" -prune -user "$(command id -u)")" ]
		then
			nvm_err "file is not writable or self-owned: $(nvm_sanitize_path "$FILE")"
			return 1
		fi
	done
	return 0
}
nvm_clang_version () {
	clang --version | command awk '{ if ($2 == "version") print $3; else if ($3 == "version") print $4 }' | command sed 's/-.*$//g'
}
nvm_command_info () {
	local COMMAND
	local INFO
	COMMAND="${1}" 
	if type "${COMMAND}" | nvm_grep -q hashed
	then
		INFO="$(type "${COMMAND}" | command sed -E 's/\(|\)//g' | command awk '{print $4}')" 
	elif type "${COMMAND}" | nvm_grep -q aliased
	then
		INFO="$(which "${COMMAND}") ($(type "${COMMAND}" | command awk '{ $1=$2=$3=$4="" ;print }' | command sed -e 's/^\ *//g' -Ee "s/\`|'//g"))" 
	elif type "${COMMAND}" | nvm_grep -q "^${COMMAND} is an alias for"
	then
		INFO="$(which "${COMMAND}") ($(type "${COMMAND}" | command awk '{ $1=$2=$3=$4=$5="" ;print }' | command sed 's/^\ *//g'))" 
	elif type "${COMMAND}" | nvm_grep -q "^${COMMAND} is /"
	then
		INFO="$(type "${COMMAND}" | command awk '{print $3}')" 
	else
		INFO="$(type "${COMMAND}")" 
	fi
	nvm_echo "${INFO}"
}
nvm_compare_checksum () {
	local FILE
	FILE="${1-}" 
	if [ -z "${FILE}" ]
	then
		nvm_err 'Provided file to checksum is empty.'
		return 4
	elif ! [ -f "${FILE}" ]
	then
		nvm_err 'Provided file to checksum does not exist.'
		return 3
	fi
	local COMPUTED_SUM
	COMPUTED_SUM="$(nvm_compute_checksum "${FILE}")" 
	local CHECKSUM
	CHECKSUM="${2-}" 
	if [ -z "${CHECKSUM}" ]
	then
		nvm_err 'Provided checksum to compare to is empty.'
		return 2
	fi
	if [ -z "${COMPUTED_SUM}" ]
	then
		nvm_err "Computed checksum of '${FILE}' is empty."
		nvm_err 'WARNING: Continuing *without checksum verification*'
		return
	elif [ "${COMPUTED_SUM}" != "${CHECKSUM}" ] && [ "${COMPUTED_SUM}" != "\\${CHECKSUM}" ]
	then
		nvm_err "Checksums do not match: '${COMPUTED_SUM}' found, '${CHECKSUM}' expected."
		return 1
	fi
	nvm_err 'Checksums matched!'
}
nvm_compute_checksum () {
	local FILE
	FILE="${1-}" 
	if [ -z "${FILE}" ]
	then
		nvm_err 'Provided file to checksum is empty.'
		return 2
	elif ! [ -f "${FILE}" ]
	then
		nvm_err 'Provided file to checksum does not exist.'
		return 1
	fi
	if nvm_has_non_aliased "sha256sum"
	then
		nvm_err 'Computing checksum with sha256sum'
		command sha256sum "${FILE}" | command awk '{print $1}'
	elif nvm_has_non_aliased "shasum"
	then
		nvm_err 'Computing checksum with shasum -a 256'
		command shasum -a 256 "${FILE}" | command awk '{print $1}'
	elif nvm_has_non_aliased "sha256"
	then
		nvm_err 'Computing checksum with sha256 -q'
		command sha256 -q "${FILE}" | command awk '{print $1}'
	elif nvm_has_non_aliased "gsha256sum"
	then
		nvm_err 'Computing checksum with gsha256sum'
		command gsha256sum "${FILE}" | command awk '{print $1}'
	elif nvm_has_non_aliased "openssl"
	then
		nvm_err 'Computing checksum with openssl dgst -sha256'
		command openssl dgst -sha256 "${FILE}" | command awk '{print $NF}'
	elif nvm_has_non_aliased "bssl"
	then
		nvm_err 'Computing checksum with bssl sha256sum'
		command bssl sha256sum "${FILE}" | command awk '{print $1}'
	elif nvm_has_non_aliased "sha1sum"
	then
		nvm_err 'Computing checksum with sha1sum'
		command sha1sum "${FILE}" | command awk '{print $1}'
	elif nvm_has_non_aliased "sha1"
	then
		nvm_err 'Computing checksum with sha1 -q'
		command sha1 -q "${FILE}"
	fi
}
nvm_curl_libz_support () {
	command curl -V 2> /dev/null | nvm_grep "^Features:" | nvm_grep -q "libz"
}
nvm_curl_use_compression () {
	nvm_curl_libz_support && nvm_version_greater_than_or_equal_to "$(nvm_curl_version)" 7.21.0
}
nvm_curl_version () {
	command curl -V | command awk '{ if ($1 == "curl") print $2 }' | command sed 's/-.*$//g'
}
nvm_die_on_prefix () {
	local NVM_DELETE_PREFIX
	NVM_DELETE_PREFIX="${1-}" 
	case "${NVM_DELETE_PREFIX}" in
		(0 | 1)  ;;
		(*) nvm_err 'First argument "delete the prefix" must be zero or one'
			return 1 ;;
	esac
	local NVM_COMMAND
	NVM_COMMAND="${2-}" 
	local NVM_VERSION_DIR
	NVM_VERSION_DIR="${3-}" 
	if [ -z "${NVM_COMMAND}" ] || [ -z "${NVM_VERSION_DIR}" ]
	then
		nvm_err 'Second argument "nvm command", and third argument "nvm version dir", must both be nonempty'
		return 2
	fi
	if [ -n "${PREFIX-}" ] && [ "$(nvm_version_path "$(node -v)")" != "${PREFIX}" ]
	then
		nvm deactivate > /dev/null 2>&1
		nvm_err "nvm is not compatible with the \"PREFIX\" environment variable: currently set to \"${PREFIX}\""
		nvm_err 'Run `unset PREFIX` to unset it.'
		return 3
	fi
	local NVM_OS
	NVM_OS="$(nvm_get_os)" 
	local NVM_NPM_CONFIG_x_PREFIX_ENV
	NVM_NPM_CONFIG_x_PREFIX_ENV="$(command awk 'BEGIN { for (name in ENVIRON) if (toupper(name) == "NPM_CONFIG_PREFIX") { print name; break } }')" 
	if [ -n "${NVM_NPM_CONFIG_x_PREFIX_ENV-}" ]
	then
		local NVM_CONFIG_VALUE
		eval "NVM_CONFIG_VALUE=\"\$${NVM_NPM_CONFIG_x_PREFIX_ENV}\""
		if [ -n "${NVM_CONFIG_VALUE-}" ] && [ "_${NVM_OS}" = "_win" ]
		then
			NVM_CONFIG_VALUE="$(cd "$NVM_CONFIG_VALUE" 2>/dev/null && pwd)" 
		fi
		if [ -n "${NVM_CONFIG_VALUE-}" ] && ! nvm_tree_contains_path "${NVM_DIR}" "${NVM_CONFIG_VALUE}"
		then
			nvm deactivate > /dev/null 2>&1
			nvm_err "nvm is not compatible with the \"${NVM_NPM_CONFIG_x_PREFIX_ENV}\" environment variable: currently set to \"${NVM_CONFIG_VALUE}\""
			nvm_err "Run \`unset ${NVM_NPM_CONFIG_x_PREFIX_ENV}\` to unset it."
			return 4
		fi
	fi
	local NVM_NPM_BUILTIN_NPMRC
	NVM_NPM_BUILTIN_NPMRC="${NVM_VERSION_DIR}/lib/node_modules/npm/npmrc" 
	if nvm_npmrc_bad_news_bears "${NVM_NPM_BUILTIN_NPMRC}"
	then
		if [ "_${NVM_DELETE_PREFIX}" = "_1" ]
		then
			npm config --loglevel=warn delete prefix --userconfig="${NVM_NPM_BUILTIN_NPMRC}"
			npm config --loglevel=warn delete globalconfig --userconfig="${NVM_NPM_BUILTIN_NPMRC}"
		else
			nvm_err "Your builtin npmrc file ($(nvm_sanitize_path "${NVM_NPM_BUILTIN_NPMRC}"))"
			nvm_err 'has a `globalconfig` and/or a `prefix` setting, which are incompatible with nvm.'
			nvm_err "Run \`${NVM_COMMAND}\` to unset it."
			return 10
		fi
	fi
	local NVM_NPM_GLOBAL_NPMRC
	NVM_NPM_GLOBAL_NPMRC="${NVM_VERSION_DIR}/etc/npmrc" 
	if nvm_npmrc_bad_news_bears "${NVM_NPM_GLOBAL_NPMRC}"
	then
		if [ "_${NVM_DELETE_PREFIX}" = "_1" ]
		then
			npm config --global --loglevel=warn delete prefix
			npm config --global --loglevel=warn delete globalconfig
		else
			nvm_err "Your global npmrc file ($(nvm_sanitize_path "${NVM_NPM_GLOBAL_NPMRC}"))"
			nvm_err 'has a `globalconfig` and/or a `prefix` setting, which are incompatible with nvm.'
			nvm_err "Run \`${NVM_COMMAND}\` to unset it."
			return 10
		fi
	fi
	local NVM_NPM_USER_NPMRC
	NVM_NPM_USER_NPMRC="${HOME}/.npmrc" 
	if nvm_npmrc_bad_news_bears "${NVM_NPM_USER_NPMRC}"
	then
		if [ "_${NVM_DELETE_PREFIX}" = "_1" ]
		then
			npm config --loglevel=warn delete prefix --userconfig="${NVM_NPM_USER_NPMRC}"
			npm config --loglevel=warn delete globalconfig --userconfig="${NVM_NPM_USER_NPMRC}"
		else
			nvm_err "Your user’s .npmrc file ($(nvm_sanitize_path "${NVM_NPM_USER_NPMRC}"))"
			nvm_err 'has a `globalconfig` and/or a `prefix` setting, which are incompatible with nvm.'
			nvm_err "Run \`${NVM_COMMAND}\` to unset it."
			return 10
		fi
	fi
	local NVM_NPM_PROJECT_NPMRC
	NVM_NPM_PROJECT_NPMRC="$(nvm_find_project_dir)/.npmrc" 
	if nvm_npmrc_bad_news_bears "${NVM_NPM_PROJECT_NPMRC}"
	then
		if [ "_${NVM_DELETE_PREFIX}" = "_1" ]
		then
			npm config --loglevel=warn delete prefix
			npm config --loglevel=warn delete globalconfig
		else
			nvm_err "Your project npmrc file ($(nvm_sanitize_path "${NVM_NPM_PROJECT_NPMRC}"))"
			nvm_err 'has a `globalconfig` and/or a `prefix` setting, which are incompatible with nvm.'
			nvm_err "Run \`${NVM_COMMAND}\` to unset it."
			return 10
		fi
	fi
}
nvm_download () {
	local sanitized_header
	sanitized_header='' 
	if [ -n "${NVM_AUTH_HEADER:-}" ]
	then
		sanitized_header="$(nvm_sanitize_auth_header "${NVM_AUTH_HEADER}")" 
	fi
	local NVM_DOWNLOADER
	NVM_DOWNLOADER='' 
	if nvm_has_executable "curl"
	then
		NVM_DOWNLOADER='curl' 
		set -- -q --fail "$@"
		if nvm_curl_use_compression
		then
			set -- --compressed "$@"
		fi
	elif nvm_has_executable "wget"
	then
		NVM_DOWNLOADER='wget' 
		local NVM_DOWNLOAD_WGET_COUNT
		NVM_DOWNLOAD_WGET_COUNT=$# 
		local NVM_DOWNLOAD_WGET_SKIP
		NVM_DOWNLOAD_WGET_SKIP=0 
		local NVM_DOWNLOAD_WGET_ARG
		for NVM_DOWNLOAD_WGET_ARG in "$@"
		do
			if [ "${NVM_DOWNLOAD_WGET_SKIP}" = '1' ]
			then
				NVM_DOWNLOAD_WGET_SKIP=0 
				continue
			fi
			case "${NVM_DOWNLOAD_WGET_ARG}" in
				('--progress-bar') set -- "$@" '--progress=bar' ;;
				('--compressed') : ;;
				('--fail') : ;;
				('-L') : ;;
				('-I') set -- "$@" '--server-response' ;;
				('-s') set -- "$@" '-q' ;;
				('-sS') set -- "$@" '-nv' ;;
				('-o') set -- "$@" '-O' ;;
				('-C') NVM_DOWNLOAD_WGET_SKIP=1 
					set -- "$@" '-c' ;;
				(*) set -- "$@" "${NVM_DOWNLOAD_WGET_ARG}" ;;
			esac
		done
		shift "${NVM_DOWNLOAD_WGET_COUNT}"
	fi
	if [ -z "${NVM_DOWNLOADER}" ]
	then
		return 0
	fi
	if [ -n "${NVM_AUTH_HEADER:-}" ]
	then
		set -- "$@" --header "Authorization: ${sanitized_header}"
	fi
	command "${NVM_DOWNLOADER}" "$@"
}
nvm_download_artifact () {
	local FLAVOR
	case "${1-}" in
		(node | iojs) FLAVOR="${1}"  ;;
		(*) nvm_err 'supported flavors: node, iojs'
			return 1 ;;
	esac
	local KIND
	case "${2-}" in
		(binary | source) KIND="${2}"  ;;
		(*) nvm_err 'supported kinds: binary, source'
			return 1 ;;
	esac
	local TYPE
	TYPE="${3-}" 
	local MIRROR
	MIRROR="$(nvm_get_mirror "${FLAVOR}" "${TYPE}")" 
	if [ -z "${MIRROR}" ]
	then
		return 2
	fi
	local VERSION
	VERSION="${4}" 
	case "${VERSION}" in
		('') nvm_err 'A version number is required.'
			return 3 ;;
		(*[!0-9A-Za-z._+-]*) nvm_err 'Invalid version: contains disallowed characters'
			return 3 ;;
	esac
	if [ "${KIND}" = 'binary' ] && ! nvm_binary_available "${VERSION}"
	then
		nvm_err "No precompiled binary available for ${VERSION}."
		return
	fi
	local SLUG
	SLUG="$(nvm_get_download_slug "${FLAVOR}" "${KIND}" "${VERSION}")" 
	local COMPRESSION
	COMPRESSION="$(nvm_get_artifact_compression "${VERSION}")" 
	local tmpdir
	if [ "${KIND}" = 'binary' ]
	then
		tmpdir="$(nvm_cache_dir)/bin/${SLUG}" 
	else
		tmpdir="$(nvm_cache_dir)/src/${SLUG}" 
	fi
	local TARBALL
	TARBALL="${tmpdir}/${SLUG}.${COMPRESSION}" 
	if [ "${NVM_OFFLINE-}" = 1 ]
	then
		if [ -r "${TARBALL}" ]
		then
			nvm_err "Offline: using cached archive $(nvm_sanitize_path "${TARBALL}")"
			nvm_echo "${TARBALL}"
			return 0
		fi
		nvm_err "Offline: no cached archive found for ${SLUG}"
		return 4
	fi
	local CHECKSUM
	CHECKSUM="$(nvm_get_checksum "${FLAVOR}" "${TYPE}" "${VERSION}" "${SLUG}" "${COMPRESSION}")" 
	command mkdir -p "${tmpdir}/files" || {
		nvm_err "creating directory ${tmpdir}/files failed"
		return 3
	}
	local TARBALL_URL
	if nvm_version_greater_than_or_equal_to "${VERSION}" 0.1.14
	then
		TARBALL_URL="${MIRROR}/${VERSION}/${SLUG}.${COMPRESSION}" 
	else
		TARBALL_URL="${MIRROR}/${SLUG}.${COMPRESSION}" 
	fi
	if [ -r "${TARBALL}" ]
	then
		nvm_err "Local cache found: $(nvm_sanitize_path "${TARBALL}")"
		if nvm_compare_checksum "${TARBALL}" "${CHECKSUM}" > /dev/null 2>&1
		then
			nvm_err "Checksums match! Using existing downloaded archive $(nvm_sanitize_path "${TARBALL}")"
			nvm_echo "${TARBALL}"
			return 0
		fi
		nvm_compare_checksum "${TARBALL}" "${CHECKSUM}"
		nvm_err "Checksum check failed!"
		nvm_err "Removing the broken local cache..."
		command rm -rf "${TARBALL}"
	fi
	nvm_err "Downloading ${TARBALL_URL}..."
	nvm_download -L -C - "${PROGRESS_BAR}" "${TARBALL_URL}" -o "${TARBALL}" || {
		command rm -rf "${TARBALL}" "${tmpdir}"
		nvm_err "download from ${TARBALL_URL} failed"
		return 4
	}
	if nvm_grep '404 Not Found' "${TARBALL}" > /dev/null
	then
		command rm -rf "${TARBALL}" "${tmpdir}"
		nvm_err "HTTP 404 at URL ${TARBALL_URL}"
		return 5
	fi
	nvm_compare_checksum "${TARBALL}" "${CHECKSUM}" || {
		command rm -rf "${tmpdir}/files"
		return 6
	}
	nvm_echo "${TARBALL}"
}
nvm_echo () {
	command printf %s\\n "$*" 2> /dev/null
}
nvm_echo_with_colors () {
	command printf %b\\n "$*" 2> /dev/null
}
nvm_ensure_default_set () {
	local VERSION
	VERSION="$1" 
	if [ -z "${VERSION}" ]
	then
		nvm_err 'nvm_ensure_default_set: a version is required'
		return 1
	elif nvm_alias default > /dev/null 2>&1
	then
		return 0
	fi
	local OUTPUT
	OUTPUT="$(nvm alias default "${VERSION}")" 
	local EXIT_CODE
	EXIT_CODE="$?" 
	nvm_echo "Creating default alias: ${OUTPUT}"
	return $EXIT_CODE
}
nvm_ensure_version_installed () {
	local PROVIDED_VERSION
	PROVIDED_VERSION="${1-}" 
	local IS_VERSION_FROM_NVMRC
	IS_VERSION_FROM_NVMRC="${2-}" 
	if [ "${PROVIDED_VERSION}" = 'system' ]
	then
		if nvm_has_system_iojs || nvm_has_system_node
		then
			return 0
		fi
		nvm_err "N/A: no system version of node/io.js is installed."
		return 1
	fi
	local LOCAL_VERSION
	local EXIT_CODE
	LOCAL_VERSION="$(nvm_version "${PROVIDED_VERSION}")" 
	EXIT_CODE="$?" 
	local NVM_VERSION_DIR
	if [ "${EXIT_CODE}" != "0" ] || ! nvm_is_version_installed "${LOCAL_VERSION}"
	then
		if VERSION="$(nvm_resolve_alias "${PROVIDED_VERSION}")" 
		then
			nvm_err "N/A: version \"${PROVIDED_VERSION} -> ${VERSION}\" is not yet installed."
		else
			local PREFIXED_VERSION
			PREFIXED_VERSION="$(nvm_ensure_version_prefix "${PROVIDED_VERSION}")" 
			nvm_err "N/A: version \"${PREFIXED_VERSION:-$PROVIDED_VERSION}\" is not yet installed."
		fi
		nvm_err ""
		if [ "${PROVIDED_VERSION}" = 'lts' ]
		then
			nvm_err '`lts` is not an alias - you may need to run `nvm install --lts` to install and `nvm use --lts` to use it.'
		elif [ "${IS_VERSION_FROM_NVMRC}" != '1' ]
		then
			nvm_err "You need to run \`nvm install ${PROVIDED_VERSION}\` to install and use it."
		else
			nvm_err 'You need to run `nvm install` to install and use the node version specified in `.nvmrc`.'
		fi
		return 1
	fi
}
nvm_ensure_version_prefix () {
	local NVM_VERSION
	NVM_VERSION="$(nvm_strip_iojs_prefix "${1-}" | command sed -e 's/^\([0-9]\)/v\1/g')" 
	if nvm_is_iojs_version "${1-}"
	then
		nvm_add_iojs_prefix "${NVM_VERSION}"
	else
		nvm_echo "${NVM_VERSION}"
	fi
}
nvm_err () {
	nvm_echo "$@" >&2
}
nvm_err_with_colors () {
	nvm_echo_with_colors "$@" >&2
}
nvm_extract_tarball () {
	if [ "$#" -ne 4 ]
	then
		nvm_err 'nvm_extract_tarball requires exactly 4 arguments'
		return 5
	fi
	local NVM_OS
	NVM_OS="${1-}" 
	local VERSION
	VERSION="${2-}" 
	local TARBALL
	TARBALL="${3-}" 
	local TMPDIR
	TMPDIR="${4-}" 
	local tar_compression_flag
	tar_compression_flag='z' 
	if nvm_supports_xz "${VERSION}"
	then
		tar_compression_flag='J' 
	fi
	local tar
	tar='tar' 
	if [ "${NVM_OS}" = 'aix' ]
	then
		tar='gtar' 
	fi
	if [ "${NVM_OS}" = 'openbsd' ]
	then
		if [ "${tar_compression_flag}" = 'J' ]
		then
			command xzcat "${TARBALL}" | "${tar}" -xf - -C "${TMPDIR}" -s '/[^\/]*\///' || return 1
		else
			command "${tar}" -x${tar_compression_flag}f "${TARBALL}" -C "${TMPDIR}" -s '/[^\/]*\///' || return 1
		fi
	else
		command "${tar}" -x${tar_compression_flag}f "${TARBALL}" -C "${TMPDIR}" --strip-components 1 --no-same-owner || return 1
	fi
}
nvm_find_nvmrc () {
	local dir
	dir="$(nvm_find_up '.nvmrc')" 
	if [ -e "${dir}/.nvmrc" ]
	then
		nvm_echo "${dir}/.nvmrc"
	fi
}
nvm_find_project_dir () {
	local path_
	path_="${PWD}" 
	while [ "${path_}" != "" ] && [ "${path_}" != '.' ] && [ ! -f "${path_}/package.json" ] && [ ! -d "${path_}/node_modules" ]
	do
		path_=${path_%/*} 
	done
	nvm_echo "${path_}"
}
nvm_find_up () {
	local path_
	path_="${PWD}" 
	while [ "${path_}" != "" ] && [ "${path_}" != '.' ] && [ ! -f "${path_}/${1-}" ]
	do
		path_=${path_%/*} 
	done
	nvm_echo "${path_}"
}
nvm_format_version () {
	local VERSION
	VERSION="$(nvm_ensure_version_prefix "${1-}")" 
	local NUM_GROUPS
	NUM_GROUPS="$(nvm_num_version_groups "${VERSION}")" 
	if [ "${NUM_GROUPS}" -lt 3 ]
	then
		nvm_format_version "${VERSION%.}.0"
	else
		nvm_echo "${VERSION}" | command cut -f1-3 -d.
	fi
}
nvm_get_arch () {
	local HOST_ARCH
	local NVM_OS
	local EXIT_CODE
	local LONG_BIT
	NVM_OS="$(nvm_get_os)" 
	if [ "_${NVM_OS}" = "_sunos" ]
	then
		if HOST_ARCH=$(pkg_info -Q MACHINE_ARCH pkg_install) 
		then
			HOST_ARCH=$(nvm_echo "${HOST_ARCH}" | command tail -1) 
		else
			HOST_ARCH=$(isainfo -n) 
		fi
	elif [ "_${NVM_OS}" = "_aix" ]
	then
		HOST_ARCH=ppc64 
	else
		HOST_ARCH="$(command uname -m)" 
		LONG_BIT="$(getconf LONG_BIT 2>/dev/null)" 
	fi
	local NVM_ARCH
	case "${HOST_ARCH}" in
		(x86_64 | amd64) NVM_ARCH="x64"  ;;
		(i*86) NVM_ARCH="x86"  ;;
		(aarch64 | armv8l) NVM_ARCH="arm64"  ;;
		(loongarch64) NVM_ARCH="loong64"  ;;
		(*) NVM_ARCH="${HOST_ARCH}"  ;;
	esac
	if [ "_${LONG_BIT}" = "_32" ] && [ "${NVM_ARCH}" = "x64" ]
	then
		NVM_ARCH="x86" 
	fi
	if [ "$(command uname)" = "Linux" ] && [ "${NVM_ARCH}" = arm64 ] && [ "$(command od -An -t x1 -j 4 -N 1 "/sbin/init" 2>/dev/null)" = ' 01' ]
	then
		NVM_ARCH=armv7l 
		HOST_ARCH=armv7l 
	fi
	if [ -f "/etc/alpine-release" ] && [ "_${NVM_OS}" = "_linux" ]
	then
		case "${NVM_ARCH}" in
			(x64) NVM_ARCH=x64-musl  ;;
			(arm64) NVM_ARCH=arm64-musl  ;;
		esac
	fi
	nvm_echo "${NVM_ARCH}"
}
nvm_get_artifact_compression () {
	local VERSION
	VERSION="${1-}" 
	local NVM_OS
	NVM_OS="$(nvm_get_os)" 
	local COMPRESSION
	COMPRESSION='tar.gz' 
	if [ "_${NVM_OS}" = '_win' ]
	then
		COMPRESSION='zip' 
	elif nvm_supports_xz "${VERSION}"
	then
		COMPRESSION='tar.xz' 
	fi
	nvm_echo "${COMPRESSION}"
}
nvm_get_checksum () {
	local FLAVOR
	case "${1-}" in
		(node | iojs) FLAVOR="${1}"  ;;
		(*) nvm_err 'supported flavors: node, iojs'
			return 2 ;;
	esac
	local MIRROR
	MIRROR="$(nvm_get_mirror "${FLAVOR}" "${2-}")" 
	if [ -z "${MIRROR}" ]
	then
		return 1
	fi
	local SHASUMS_URL
	if [ "$(nvm_get_checksum_alg)" = 'sha-256' ]
	then
		SHASUMS_URL="${MIRROR}/${3}/SHASUMS256.txt" 
	else
		SHASUMS_URL="${MIRROR}/${3}/SHASUMS.txt" 
	fi
	nvm_download -L -s "${SHASUMS_URL}" -o - | command awk -v tarball="${4}.${5}" '{ if (tarball == $2) print $1 }'
}
nvm_get_checksum_alg () {
	local NVM_CHECKSUM_BIN
	NVM_CHECKSUM_BIN="$(nvm_get_checksum_binary 2>/dev/null)" 
	case "${NVM_CHECKSUM_BIN-}" in
		(sha256sum | shasum | sha256 | gsha256sum | openssl | bssl) nvm_echo 'sha-256' ;;
		(sha1sum | sha1) nvm_echo 'sha-1' ;;
		(*) nvm_get_checksum_binary
			return $? ;;
	esac
}
nvm_get_checksum_binary () {
	if nvm_has_non_aliased 'sha256sum'
	then
		nvm_echo 'sha256sum'
	elif nvm_has_non_aliased 'shasum'
	then
		nvm_echo 'shasum'
	elif nvm_has_non_aliased 'sha256'
	then
		nvm_echo 'sha256'
	elif nvm_has_non_aliased 'gsha256sum'
	then
		nvm_echo 'gsha256sum'
	elif nvm_has_non_aliased 'openssl'
	then
		nvm_echo 'openssl'
	elif nvm_has_non_aliased 'bssl'
	then
		nvm_echo 'bssl'
	elif nvm_has_non_aliased 'sha1sum'
	then
		nvm_echo 'sha1sum'
	elif nvm_has_non_aliased 'sha1'
	then
		nvm_echo 'sha1'
	else
		nvm_err 'Unaliased sha256sum, shasum, sha256, gsha256sum, openssl, or bssl not found.'
		nvm_err 'Unaliased sha1sum or sha1 not found.'
		return 1
	fi
}
nvm_get_colors () {
	local COLOR
	local SYS_COLOR
	local COLORS
	COLORS="${NVM_COLORS:-bygre}" 
	case $1 in
		(1) COLOR=$(nvm_print_color_code "$(echo "$COLORS" | awk '{ print substr($0, 1, 1); }')")  ;;
		(2) COLOR=$(nvm_print_color_code "$(echo "$COLORS" | awk '{ print substr($0, 2, 1); }')")  ;;
		(3) COLOR=$(nvm_print_color_code "$(echo "$COLORS" | awk '{ print substr($0, 3, 1); }')")  ;;
		(4) COLOR=$(nvm_print_color_code "$(echo "$COLORS" | awk '{ print substr($0, 4, 1); }')")  ;;
		(5) COLOR=$(nvm_print_color_code "$(echo "$COLORS" | awk '{ print substr($0, 5, 1); }')")  ;;
		(6) SYS_COLOR=$(nvm_print_color_code "$(echo "$COLORS" | awk '{ print substr($0, 2, 1); }')") 
			COLOR=$(nvm_echo "$SYS_COLOR" | command tr '0;' '1;')  ;;
		(*) nvm_err "Invalid color index, ${1-}"
			return 1 ;;
	esac
	nvm_echo "$COLOR"
}
nvm_get_default_packages () {
	local NVM_DEFAULT_PACKAGE_FILE
	NVM_DEFAULT_PACKAGE_FILE="${NVM_DIR}/default-packages" 
	if [ -f "${NVM_DEFAULT_PACKAGE_FILE}" ]
	then
		command awk -v filename="${NVM_DEFAULT_PACKAGE_FILE}" '
      /^[ \t]*#/ { next }                           # Skip lines that begin with #
      /^[ \t]*$/ { next }                           # Skip empty lines
      /[ \t]/ && !/^[ \t]*#/ {
        print "Only one package per line is allowed in `" filename "`. Please remove any lines with multiple space-separated values." > "/dev/stderr"
        err = 1
        exit 1
      }
      {
        if (NR > 1 && !prev_space) printf " "
        printf "%s", $0
        prev_space = 0
      }
    ' "${NVM_DEFAULT_PACKAGE_FILE}"
	fi
}
nvm_get_download_slug () {
	local FLAVOR
	case "${1-}" in
		(node | iojs) FLAVOR="${1}"  ;;
		(*) nvm_err 'supported flavors: node, iojs'
			return 1 ;;
	esac
	local KIND
	case "${2-}" in
		(binary | source) KIND="${2}"  ;;
		(*) nvm_err 'supported kinds: binary, source'
			return 2 ;;
	esac
	local VERSION
	VERSION="${3-}" 
	local NVM_OS
	NVM_OS="$(nvm_get_os)" 
	local NVM_ARCH
	NVM_ARCH="$(nvm_get_arch)" 
	if ! nvm_is_merged_node_version "${VERSION}"
	then
		if [ "${NVM_ARCH}" = 'armv6l' ] || [ "${NVM_ARCH}" = 'armv7l' ]
		then
			NVM_ARCH="arm-pi" 
		fi
	fi
	if nvm_version_greater '16.0.0' "${VERSION}" && [ "_${NVM_OS}" = '_darwin' ] && [ "${NVM_ARCH}" = 'arm64' ]
	then
		NVM_ARCH=x64 
	fi
	if [ "${KIND}" = 'binary' ]
	then
		nvm_echo "${FLAVOR}-${VERSION}-${NVM_OS}-${NVM_ARCH}"
	elif [ "${KIND}" = 'source' ]
	then
		nvm_echo "${FLAVOR}-${VERSION}"
	fi
}
nvm_get_latest () {
	local NVM_LATEST_URL
	local CURL_COMPRESSED_FLAG
	if nvm_has_executable "curl"
	then
		if nvm_curl_use_compression
		then
			CURL_COMPRESSED_FLAG="--compressed" 
		fi
		NVM_LATEST_URL="$(command curl ${CURL_COMPRESSED_FLAG:-} -q -w "%{url_effective}\\n" -L -s -S https://latest.nvm.sh -o /dev/null)" 
	elif nvm_has_executable "wget"
	then
		NVM_LATEST_URL="$(command wget -q https://latest.nvm.sh --server-response -O /dev/null 2>&1 | command awk '/^  Location: /{DEST=$2} END{ print DEST }')" 
	else
		nvm_err 'nvm needs curl or wget to proceed.'
		return 1
	fi
	if [ -z "${NVM_LATEST_URL}" ]
	then
		nvm_err "https://latest.nvm.sh did not redirect to the latest release on GitHub"
		return 2
	fi
	nvm_echo "${NVM_LATEST_URL##*/}"
}
nvm_get_make_jobs () {
	if nvm_is_natural_num "${1-}"
	then
		NVM_MAKE_JOBS="$1" 
		nvm_echo "number of \`make\` jobs: ${NVM_MAKE_JOBS}"
		return
	elif [ -n "${1-}" ]
	then
		unset NVM_MAKE_JOBS
		nvm_err "$1 is invalid for number of \`make\` jobs, must be a natural number"
	fi
	local NVM_OS
	NVM_OS="$(nvm_get_os)" 
	local NVM_CPU_CORES
	case "_${NVM_OS}" in
		("_linux") NVM_CPU_CORES="$(nvm_grep -c -E '^processor.+: [0-9]+' /proc/cpuinfo)"  ;;
		("_freebsd" | "_darwin" | "_openbsd") NVM_CPU_CORES="$(sysctl -n hw.ncpu)"  ;;
		("_sunos") NVM_CPU_CORES="$(psrinfo | wc -l)"  ;;
		("_aix") NVM_CPU_CORES="$(pmcycles -m | wc -l)"  ;;
	esac
	if ! nvm_is_natural_num "${NVM_CPU_CORES}"
	then
		nvm_err 'Can not determine how many core(s) are available, running in single-threaded mode.'
		nvm_err 'Please report an issue on GitHub to help us make nvm run faster on your computer!'
		NVM_MAKE_JOBS=1 
	else
		nvm_echo "Detected that you have ${NVM_CPU_CORES} CPU core(s)"
		if [ "${NVM_CPU_CORES}" -gt 2 ]
		then
			NVM_MAKE_JOBS=$((NVM_CPU_CORES - 1)) 
			nvm_echo "Running with ${NVM_MAKE_JOBS} threads to speed up the build"
		else
			NVM_MAKE_JOBS=1 
			nvm_echo 'Number of CPU core(s) less than or equal to 2, running in single-threaded mode'
		fi
	fi
}
nvm_get_minor_version () {
	local VERSION
	VERSION="$1" 
	if [ -z "${VERSION}" ]
	then
		nvm_err 'a version is required'
		return 1
	fi
	case "${VERSION}" in
		(v | .* | *..* | v*[!.0123456789]* | [!v]*[!.0123456789]* | [!v0123456789]* | v[!0123456789]*) nvm_err 'invalid version number'
			return 2 ;;
	esac
	local PREFIXED_VERSION
	PREFIXED_VERSION="$(nvm_format_version "${VERSION}")" 
	local MINOR
	MINOR="$(nvm_echo "${PREFIXED_VERSION}" | nvm_grep -e '^v' | command cut -c2- | command cut -d . -f 1,2)" 
	if [ -z "${MINOR}" ]
	then
		nvm_err 'invalid version number! (please report this)'
		return 3
	fi
	nvm_echo "${MINOR}"
}
nvm_get_mirror () {
	local NVM_MIRROR
	NVM_MIRROR='' 
	case "${1}-${2}" in
		(node-std) NVM_MIRROR="${NVM_NODEJS_ORG_MIRROR:-https://nodejs.org/dist}"  ;;
		(iojs-std) NVM_MIRROR="${NVM_IOJS_ORG_MIRROR:-https://iojs.org/dist}"  ;;
		(*) nvm_err 'unknown type of node.js or io.js release'
			return 1 ;;
	esac
	case "${NVM_MIRROR}" in
		(*\`* | *\\* | *\'* | *\(* | *' '*) nvm_err '$NVM_NODEJS_ORG_MIRROR and $NVM_IOJS_ORG_MIRROR may only contain a URL'
			return 2 ;;
	esac
	if ! nvm_echo "${NVM_MIRROR}" | command awk '{ if ($0 !~ /^https?:\/\/[a-zA-Z0-9.\/_-]+$/) exit 1 }'
	then
		nvm_err '$NVM_NODEJS_ORG_MIRROR and $NVM_IOJS_ORG_MIRROR may only contain a URL'
		return 2
	fi
	nvm_echo "${NVM_MIRROR}"
}
nvm_get_os () {
	local NVM_UNAME
	NVM_UNAME="$(command uname -a)" 
	local NVM_OS
	case "${NVM_UNAME}" in
		(Linux\ *) NVM_OS=linux  ;;
		(Darwin\ *) NVM_OS=darwin  ;;
		(SunOS\ *) NVM_OS=sunos  ;;
		(FreeBSD\ *) NVM_OS=freebsd  ;;
		(OpenBSD\ *) NVM_OS=openbsd  ;;
		(AIX\ *) NVM_OS=aix  ;;
		(CYGWIN* | MSYS* | MINGW*) NVM_OS=win  ;;
	esac
	nvm_echo "${NVM_OS-}"
}
nvm_grep () {
	GREP_OPTIONS='' command grep "$@"
}
nvm_has () {
	type "${1-}" > /dev/null 2>&1
}
nvm_has_colors () {
	local NVM_NUM_COLORS
	if nvm_has tput
	then
		NVM_NUM_COLORS="$(command tput -T "${TERM:-vt100}" colors)" 
	fi
	[ -t 1 ] && [ "${NVM_NUM_COLORS:--1}" -ge 8 ] && [ "${NVM_NO_COLORS-}" != '--no-colors' ]
}
nvm_has_executable () {
	(
		unalias "${1-}" 2> /dev/null || true
		unset -f "${1-}" 2> /dev/null || true
		command -v "${1-}" > /dev/null 2>&1
	)
}
nvm_has_non_aliased () {
	nvm_has "${1-}" && ! nvm_is_alias "${1-}"
}
nvm_has_solaris_binary () {
	local VERSION="${1-}" 
	if nvm_is_merged_node_version "${VERSION}"
	then
		return 0
	elif nvm_is_iojs_version "${VERSION}"
	then
		nvm_iojs_version_has_solaris_binary "${VERSION}"
	else
		nvm_node_version_has_solaris_binary "${VERSION}"
	fi
}
nvm_has_system_iojs () {
	[ "$(nvm deactivate >/dev/null 2>&1 && command -v iojs)" != '' ]
}
nvm_has_system_node () {
	[ "$(nvm deactivate >/dev/null 2>&1 && command -v node)" != '' ]
}
nvm_install_binary () {
	local FLAVOR
	case "${1-}" in
		(node | iojs) FLAVOR="${1}"  ;;
		(*) nvm_err 'supported flavors: node, iojs'
			return 4 ;;
	esac
	local TYPE
	TYPE="${2-}" 
	local PREFIXED_VERSION
	PREFIXED_VERSION="${3-}" 
	if [ -z "${PREFIXED_VERSION}" ]
	then
		nvm_err 'A version number is required.'
		return 3
	fi
	local nosource
	nosource="${4-}" 
	local VERSION
	VERSION="$(nvm_strip_iojs_prefix "${PREFIXED_VERSION}")" 
	local NVM_OS
	NVM_OS="$(nvm_get_os)" 
	if [ -z "${NVM_OS}" ]
	then
		return 2
	fi
	local TARBALL
	local TMPDIR
	local PROGRESS_BAR
	local NODE_OR_IOJS
	if [ "${FLAVOR}" = 'node' ]
	then
		NODE_OR_IOJS="${FLAVOR}" 
	elif [ "${FLAVOR}" = 'iojs' ]
	then
		NODE_OR_IOJS="io.js" 
	fi
	if [ "${NVM_NO_PROGRESS-}" = "1" ]
	then
		PROGRESS_BAR="-sS" 
	else
		PROGRESS_BAR="--progress-bar" 
	fi
	nvm_echo "Downloading and installing ${NODE_OR_IOJS-} ${VERSION}..."
	TARBALL="$(PROGRESS_BAR="${PROGRESS_BAR}" nvm_download_artifact "${FLAVOR}" binary "${TYPE-}" "${VERSION}" | command tail -1)" 
	if [ -f "${TARBALL}" ]
	then
		TMPDIR="$(dirname "${TARBALL}")/files" 
	fi
	if nvm_install_binary_extract "${NVM_OS}" "${PREFIXED_VERSION}" "${VERSION}" "${TARBALL}" "${TMPDIR}"
	then
		if [ -n "${ALIAS-}" ]
		then
			nvm alias "${ALIAS}" "${provided_version}"
		fi
		return 0
	fi
	if [ "${nosource-}" = '1' ]
	then
		nvm_err 'Binary download failed. Download from source aborted.'
		return 2
	fi
	nvm_err 'Binary download failed, trying source.'
	if [ -n "${TMPDIR-}" ]
	then
		command rm -rf "${TMPDIR}"
	fi
	return 1
}
nvm_install_binary_extract () {
	if [ "$#" -ne 5 ]
	then
		nvm_err 'nvm_install_binary_extract needs 5 parameters'
		return 1
	fi
	local NVM_OS
	local PREFIXED_VERSION
	local VERSION
	local TARBALL
	local TMPDIR
	NVM_OS="${1}" 
	PREFIXED_VERSION="${2}" 
	VERSION="${3}" 
	TARBALL="${4}" 
	TMPDIR="${5}" 
	local VERSION_PATH
	[ -n "${TMPDIR-}" ] && command mkdir -p "${TMPDIR}" && VERSION_PATH="$(nvm_version_path "${PREFIXED_VERSION}")"  || return 1
	if [ "${NVM_OS}" = 'win' ]
	then
		VERSION_PATH="${VERSION_PATH}/bin" 
		command unzip -q "${TARBALL}" -d "${TMPDIR}" || return 1
	else
		nvm_extract_tarball "${NVM_OS}" "${VERSION}" "${TARBALL}" "${TMPDIR}"
	fi
	command mkdir -p "${VERSION_PATH}" || return 1
	if [ "${NVM_OS}" = 'win' ]
	then
		command mv "${TMPDIR}/"*/* "${VERSION_PATH}/" || return 1
		command chmod +x "${VERSION_PATH}"/node.exe || return 1
		command chmod +x "${VERSION_PATH}"/npm || return 1
		command chmod +x "${VERSION_PATH}"/npx 2> /dev/null
	else
		command mv "${TMPDIR}/"* "${VERSION_PATH}" || return 1
	fi
	command rm -rf "${TMPDIR}"
	return 0
}
nvm_install_default_packages () {
	local DEFAULT_PACKAGES
	DEFAULT_PACKAGES="$(nvm_get_default_packages)" 
	EXIT_CODE=$? 
	if [ $EXIT_CODE -ne 0 ] || [ -z "${DEFAULT_PACKAGES}" ]
	then
		return $EXIT_CODE
	fi
	nvm_echo "Installing default global packages from ${NVM_DIR}/default-packages..."
	nvm_echo "npm install -g --quiet ${DEFAULT_PACKAGES}"
	if ! nvm_echo "${DEFAULT_PACKAGES}" | command xargs npm install -g --quiet
	then
		nvm_err "Failed installing default packages. Please check if your default-packages file or a package in it has problems!"
		return 1
	fi
}
nvm_install_latest_npm () {
	nvm_echo 'Attempting to upgrade to the latest working version of npm...'
	local NODE_VERSION
	NODE_VERSION="$(nvm_strip_iojs_prefix "$(nvm_ls_current)")" 
	local NPM_VERSION
	NPM_VERSION="$(npm --version 2>/dev/null)" 
	if [ "${NODE_VERSION}" = 'system' ]
	then
		NODE_VERSION="$(node --version)" 
	elif [ "${NODE_VERSION}" = 'none' ]
	then
		nvm_echo "Detected node version ${NODE_VERSION}, npm version v${NPM_VERSION}"
		NODE_VERSION='' 
	fi
	if [ -z "${NODE_VERSION}" ]
	then
		nvm_err 'Unable to obtain node version.'
		return 1
	fi
	if [ -z "${NPM_VERSION}" ]
	then
		nvm_err 'Unable to obtain npm version.'
		return 2
	fi
	local NVM_NPM_CMD
	NVM_NPM_CMD='npm' 
	if [ "${NVM_DEBUG-}" = 1 ]
	then
		nvm_echo "Detected node version ${NODE_VERSION}, npm version v${NPM_VERSION}"
		NVM_NPM_CMD='nvm_echo npm' 
	fi
	local NVM_IS_0_6
	NVM_IS_0_6=0 
	if nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 0.6.0 && nvm_version_greater 0.7.0 "${NODE_VERSION}"
	then
		NVM_IS_0_6=1 
	fi
	local NVM_IS_0_9
	NVM_IS_0_9=0 
	if nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 0.9.0 && nvm_version_greater 0.10.0 "${NODE_VERSION}"
	then
		NVM_IS_0_9=1 
	fi
	if [ $NVM_IS_0_6 -eq 1 ]
	then
		nvm_echo '* `node` v0.6.x can only upgrade to `npm` v1.3.x'
		$NVM_NPM_CMD install -g npm@1.3
	elif [ $NVM_IS_0_9 -eq 0 ]
	then
		if nvm_version_greater_than_or_equal_to "${NPM_VERSION}" 1.0.0 && nvm_version_greater 2.0.0 "${NPM_VERSION}"
		then
			nvm_echo '* `npm` v1.x needs to first jump to `npm` v1.4.28 to be able to upgrade further'
			$NVM_NPM_CMD install -g npm@1.4.28
		elif nvm_version_greater_than_or_equal_to "${NPM_VERSION}" 2.0.0 && nvm_version_greater 3.0.0 "${NPM_VERSION}"
		then
			nvm_echo '* `npm` v2.x needs to first jump to the latest v2 to be able to upgrade further'
			$NVM_NPM_CMD install -g npm@2
		fi
	fi
	if [ $NVM_IS_0_9 -eq 1 ] || [ $NVM_IS_0_6 -eq 1 ]
	then
		nvm_echo '* node v0.6 and v0.9 are unable to upgrade further'
	elif nvm_version_greater 1.1.0 "${NODE_VERSION}"
	then
		nvm_echo '* `npm` v4.5.x is the last version that works on `node` versions < v1.1.0'
		$NVM_NPM_CMD install -g npm@4.5
	elif nvm_version_greater 4.0.0 "${NODE_VERSION}"
	then
		nvm_echo '* `npm` v5 and higher do not work on `node` versions below v4.0.0'
		$NVM_NPM_CMD install -g npm@4
	elif [ $NVM_IS_0_9 -eq 0 ] && [ $NVM_IS_0_6 -eq 0 ]
	then
		local NVM_IS_4_4_OR_BELOW
		NVM_IS_4_4_OR_BELOW=0 
		if nvm_version_greater 4.5.0 "${NODE_VERSION}"
		then
			NVM_IS_4_4_OR_BELOW=1 
		fi
		local NVM_IS_5_OR_ABOVE
		NVM_IS_5_OR_ABOVE=0 
		if [ $NVM_IS_4_4_OR_BELOW -eq 0 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 5.0.0
		then
			NVM_IS_5_OR_ABOVE=1 
		fi
		local NVM_IS_6_OR_ABOVE
		NVM_IS_6_OR_ABOVE=0 
		local NVM_IS_6_2_OR_ABOVE
		NVM_IS_6_2_OR_ABOVE=0 
		if [ $NVM_IS_5_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 6.0.0
		then
			NVM_IS_6_OR_ABOVE=1 
			if nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 6.2.0
			then
				NVM_IS_6_2_OR_ABOVE=1 
			fi
		fi
		local NVM_IS_9_OR_ABOVE
		NVM_IS_9_OR_ABOVE=0 
		local NVM_IS_9_3_OR_ABOVE
		NVM_IS_9_3_OR_ABOVE=0 
		if [ $NVM_IS_6_2_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 9.0.0
		then
			NVM_IS_9_OR_ABOVE=1 
			if nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 9.3.0
			then
				NVM_IS_9_3_OR_ABOVE=1 
			fi
		fi
		local NVM_IS_10_OR_ABOVE
		NVM_IS_10_OR_ABOVE=0 
		if [ $NVM_IS_9_3_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 10.0.0
		then
			NVM_IS_10_OR_ABOVE=1 
		fi
		local NVM_IS_12_LTS_OR_ABOVE
		NVM_IS_12_LTS_OR_ABOVE=0 
		if [ $NVM_IS_10_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 12.13.0
		then
			NVM_IS_12_LTS_OR_ABOVE=1 
		fi
		local NVM_IS_13_OR_ABOVE
		NVM_IS_13_OR_ABOVE=0 
		if [ $NVM_IS_12_LTS_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 13.0.0
		then
			NVM_IS_13_OR_ABOVE=1 
		fi
		local NVM_IS_14_LTS_OR_ABOVE
		NVM_IS_14_LTS_OR_ABOVE=0 
		if [ $NVM_IS_13_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 14.15.0
		then
			NVM_IS_14_LTS_OR_ABOVE=1 
		fi
		local NVM_IS_14_17_OR_ABOVE
		NVM_IS_14_17_OR_ABOVE=0 
		if [ $NVM_IS_14_LTS_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 14.17.0
		then
			NVM_IS_14_17_OR_ABOVE=1 
		fi
		local NVM_IS_15_OR_ABOVE
		NVM_IS_15_OR_ABOVE=0 
		if [ $NVM_IS_14_LTS_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 15.0.0
		then
			NVM_IS_15_OR_ABOVE=1 
		fi
		local NVM_IS_16_OR_ABOVE
		NVM_IS_16_OR_ABOVE=0 
		if [ $NVM_IS_15_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 16.0.0
		then
			NVM_IS_16_OR_ABOVE=1 
		fi
		local NVM_IS_16_LTS_OR_ABOVE
		NVM_IS_16_LTS_OR_ABOVE=0 
		if [ $NVM_IS_16_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 16.13.0
		then
			NVM_IS_16_LTS_OR_ABOVE=1 
		fi
		local NVM_IS_17_OR_ABOVE
		NVM_IS_17_OR_ABOVE=0 
		if [ $NVM_IS_16_LTS_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 17.0.0
		then
			NVM_IS_17_OR_ABOVE=1 
		fi
		local NVM_IS_18_OR_ABOVE
		NVM_IS_18_OR_ABOVE=0 
		if [ $NVM_IS_17_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 18.0.0
		then
			NVM_IS_18_OR_ABOVE=1 
		fi
		local NVM_IS_18_17_OR_ABOVE
		NVM_IS_18_17_OR_ABOVE=0 
		if [ $NVM_IS_18_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 18.17.0
		then
			NVM_IS_18_17_OR_ABOVE=1 
		fi
		local NVM_IS_19_OR_ABOVE
		NVM_IS_19_OR_ABOVE=0 
		if [ $NVM_IS_18_17_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 19.0.0
		then
			NVM_IS_19_OR_ABOVE=1 
		fi
		local NVM_IS_20_5_OR_ABOVE
		NVM_IS_20_5_OR_ABOVE=0 
		if [ $NVM_IS_19_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 20.5.0
		then
			NVM_IS_20_5_OR_ABOVE=1 
		fi
		local NVM_IS_20_17_OR_ABOVE
		NVM_IS_20_17_OR_ABOVE=0 
		if [ $NVM_IS_20_5_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 20.17.0
		then
			NVM_IS_20_17_OR_ABOVE=1 
		fi
		local NVM_IS_21_OR_ABOVE
		NVM_IS_21_OR_ABOVE=0 
		if [ $NVM_IS_20_17_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 21.0.0
		then
			NVM_IS_21_OR_ABOVE=1 
		fi
		local NVM_IS_22_9_OR_ABOVE
		NVM_IS_22_9_OR_ABOVE=0 
		if [ $NVM_IS_21_OR_ABOVE -eq 1 ] && nvm_version_greater_than_or_equal_to "${NODE_VERSION}" 22.9.0
		then
			NVM_IS_22_9_OR_ABOVE=1 
		fi
		if [ $NVM_IS_4_4_OR_BELOW -eq 1 ] || {
				[ $NVM_IS_5_OR_ABOVE -eq 1 ] && nvm_version_greater 5.10.0 "${NODE_VERSION}"
			}
		then
			nvm_echo '* `npm` `v5.3.x` is the last version that works on `node` 4.x versions below v4.4, or 5.x versions below v5.10, due to `Buffer.alloc`'
			$NVM_NPM_CMD install -g npm@5.3
		elif [ $NVM_IS_4_4_OR_BELOW -eq 0 ] && nvm_version_greater 4.7.0 "${NODE_VERSION}"
		then
			nvm_echo '* `npm` `v5.4.1` is the last version that works on `node` `v4.5` and `v4.6`'
			$NVM_NPM_CMD install -g npm@5.4.1
		elif [ $NVM_IS_6_OR_ABOVE -eq 0 ]
		then
			nvm_echo '* `npm` `v5.x` is the last version that works on `node` below `v6.0.0`'
			$NVM_NPM_CMD install -g npm@5
		elif {
				[ $NVM_IS_6_OR_ABOVE -eq 1 ] && [ $NVM_IS_6_2_OR_ABOVE -eq 0 ]
			} || {
				[ $NVM_IS_9_OR_ABOVE -eq 1 ] && [ $NVM_IS_9_3_OR_ABOVE -eq 0 ]
			}
		then
			nvm_echo '* `npm` `v6.9` is the last version that works on `node` `v6.0.x`, `v6.1.x`, `v9.0.x`, `v9.1.x`, or `v9.2.x`'
			$NVM_NPM_CMD install -g npm@6.9
		elif [ $NVM_IS_10_OR_ABOVE -eq 0 ]
		then
			if nvm_version_greater 4.4.4 "${NPM_VERSION}"
			then
				nvm_echo '* `npm` `v4.4.4` or later is required to install npm v6.14.18'
				$NVM_NPM_CMD install -g npm@4
			fi
			nvm_echo '* `npm` `v6.x` is the last version that works on `node` below `v10.0.0`'
			$NVM_NPM_CMD install -g npm@6
		elif [ $NVM_IS_12_LTS_OR_ABOVE -eq 0 ] || {
				[ $NVM_IS_13_OR_ABOVE -eq 1 ] && [ $NVM_IS_14_LTS_OR_ABOVE -eq 0 ]
			} || {
				[ $NVM_IS_15_OR_ABOVE -eq 1 ] && [ $NVM_IS_16_OR_ABOVE -eq 0 ]
			}
		then
			nvm_echo '* `npm` `v7.x` is the last version that works on `node` `v13`, `v15`, below `v12.13`, or `v14.0` - `v14.15`'
			$NVM_NPM_CMD install -g npm@7
		elif {
				[ $NVM_IS_12_LTS_OR_ABOVE -eq 1 ] && [ $NVM_IS_13_OR_ABOVE -eq 0 ]
			} || {
				[ $NVM_IS_14_LTS_OR_ABOVE -eq 1 ] && [ $NVM_IS_14_17_OR_ABOVE -eq 0 ]
			} || {
				[ $NVM_IS_16_OR_ABOVE -eq 1 ] && [ $NVM_IS_16_LTS_OR_ABOVE -eq 0 ]
			} || {
				[ $NVM_IS_17_OR_ABOVE -eq 1 ] && [ $NVM_IS_18_OR_ABOVE -eq 0 ]
			}
		then
			nvm_echo '* `npm` `v8.6` is the last version that works on `node` `v12`, `v14.13` - `v14.16`, or `v16.0` - `v16.12`'
			$NVM_NPM_CMD install -g npm@8.6
		elif [ $NVM_IS_18_17_OR_ABOVE -eq 0 ] || {
				[ $NVM_IS_19_OR_ABOVE -eq 1 ] && [ $NVM_IS_20_5_OR_ABOVE -eq 0 ]
			}
		then
			nvm_echo '* `npm` `v9.x` is the last version that works on `node` `< v18.17`, `v19`, or `v20.0` - `v20.4`'
			$NVM_NPM_CMD install -g npm@9
		elif [ $NVM_IS_20_17_OR_ABOVE -eq 0 ] || {
				[ $NVM_IS_21_OR_ABOVE -eq 1 ] && [ $NVM_IS_22_9_OR_ABOVE -eq 0 ]
			}
		then
			nvm_echo '* `npm` `v10.x` is the last version that works on `node` `< v20.17`, `v21`, or `v22.0` - `v22.8`'
			$NVM_NPM_CMD install -g npm@10
		else
			nvm_echo '* Installing latest `npm`; if this does not work on your node version, please report a bug!'
			$NVM_NPM_CMD install -g npm
		fi
	fi
	nvm_echo "* npm upgraded to: v$(npm --version 2>/dev/null)"
}
nvm_install_npm_if_needed () {
	local VERSION
	VERSION="$(nvm_ls_current)" 
	if ! nvm_has "npm"
	then
		nvm_echo 'Installing npm...'
		if nvm_version_greater 0.2.0 "${VERSION}"
		then
			nvm_err 'npm requires node v0.2.3 or higher'
		elif nvm_version_greater_than_or_equal_to "${VERSION}" 0.2.0
		then
			if nvm_version_greater 0.2.3 "${VERSION}"
			then
				nvm_err 'npm requires node v0.2.3 or higher'
			else
				nvm_download -L https://npmjs.org/install.sh -o - | clean=yes npm_install=0.2.19 sh
			fi
		else
			nvm_download -L https://npmjs.org/install.sh -o - | clean=yes sh
		fi
	fi
	return $?
}
nvm_install_source () {
	local FLAVOR
	case "${1-}" in
		(node | iojs) FLAVOR="${1}"  ;;
		(*) nvm_err 'supported flavors: node, iojs'
			return 4 ;;
	esac
	local TYPE
	TYPE="${2-}" 
	local PREFIXED_VERSION
	PREFIXED_VERSION="${3-}" 
	if [ -z "${PREFIXED_VERSION}" ]
	then
		nvm_err 'A version number is required.'
		return 3
	fi
	local VERSION
	VERSION="$(nvm_strip_iojs_prefix "${PREFIXED_VERSION}")" 
	local NVM_MAKE_JOBS
	NVM_MAKE_JOBS="${4-}" 
	local ADDITIONAL_PARAMETERS
	ADDITIONAL_PARAMETERS="${5-}" 
	local NVM_ARCH
	NVM_ARCH="$(nvm_get_arch)" 
	if [ "${NVM_ARCH}" = 'armv6l' ] || [ "${NVM_ARCH}" = 'armv7l' ]
	then
		if [ -n "${ADDITIONAL_PARAMETERS}" ]
		then
			ADDITIONAL_PARAMETERS="--without-snapshot ${ADDITIONAL_PARAMETERS}" 
		else
			ADDITIONAL_PARAMETERS='--without-snapshot' 
		fi
	fi
	if [ -n "${ADDITIONAL_PARAMETERS}" ]
	then
		nvm_echo "Additional options while compiling: ${ADDITIONAL_PARAMETERS}"
	fi
	local NVM_OS
	NVM_OS="$(nvm_get_os)" 
	local make
	local MAKE_CXX
	local MAKE_SHELL_OVERRIDE
	if nvm_version_greater "0.12.0" "${VERSION}"
	then
		MAKE_SHELL_OVERRIDE=' SHELL=/bin/sh' 
	fi
	make="make${MAKE_SHELL_OVERRIDE-}" 
	case "${NVM_OS}" in
		('freebsd' | 'openbsd') make="gmake${MAKE_SHELL_OVERRIDE-}" 
			MAKE_CXX="CC=${CC:-cc} CXX=${CXX:-c++}"  ;;
		('darwin') MAKE_CXX="CC=${CC:-cc} CXX=${CXX:-c++}"  ;;
		('aix') make="gmake${MAKE_SHELL_OVERRIDE-}"  ;;
	esac
	if nvm_has "clang++" && nvm_has "clang" && nvm_version_greater_than_or_equal_to "$(nvm_clang_version)" 3.5
	then
		if [ -z "${CC-}" ] || [ -z "${CXX-}" ]
		then
			nvm_echo "Clang v3.5+ detected! CC or CXX not specified, will use Clang as C/C++ compiler!"
			MAKE_CXX="CC=${CC:-cc} CXX=${CXX:-c++}" 
		fi
	fi
	local TARBALL
	local TMPDIR
	local VERSION_PATH
	if [ "${NVM_NO_PROGRESS-}" = "1" ]
	then
		PROGRESS_BAR="-sS" 
	else
		PROGRESS_BAR="--progress-bar" 
	fi
	nvm_is_zsh && setopt local_options shwordsplit
	TARBALL="$(PROGRESS_BAR="${PROGRESS_BAR}" nvm_download_artifact "${FLAVOR}" source "${TYPE}" "${VERSION}" | command tail -1)"  && [ -f "${TARBALL}" ] && TMPDIR="$(dirname "${TARBALL}")/files"  && if ! (
			command mkdir -p "${TMPDIR}" && nvm_extract_tarball "${NVM_OS}" "${VERSION}" "${TARBALL}" "${TMPDIR}" && VERSION_PATH="$(nvm_version_path "${PREFIXED_VERSION}")"  && nvm_cd "${TMPDIR}" && nvm_echo '$>'./configure --prefix="${VERSION_PATH}" $ADDITIONAL_PARAMETERS'<' && ./configure --prefix="${VERSION_PATH}" $ADDITIONAL_PARAMETERS && $make -j "${NVM_MAKE_JOBS}" ${MAKE_CXX-} && command rm -f "${VERSION_PATH}" 2> /dev/null && $make -j "${NVM_MAKE_JOBS}" ${MAKE_CXX-} install
		)
	then
		nvm_err "nvm: install ${VERSION} failed!"
		command rm -rf "${TMPDIR-}"
		return 1
	fi
}
nvm_iojs_prefix () {
	nvm_echo 'iojs'
}
nvm_iojs_version_has_solaris_binary () {
	local IOJS_VERSION
	IOJS_VERSION="$1" 
	local STRIPPED_IOJS_VERSION
	STRIPPED_IOJS_VERSION="$(nvm_strip_iojs_prefix "${IOJS_VERSION}")" 
	if [ "_${STRIPPED_IOJS_VERSION}" = "_${IOJS_VERSION}" ]
	then
		return 1
	fi
	nvm_version_greater_than_or_equal_to "${STRIPPED_IOJS_VERSION}" v3.3.1
}
nvm_is_alias () {
	\alias "${1-}" > /dev/null 2>&1
}
nvm_is_iojs_version () {
	case "${1-}" in
		(iojs-*) return 0 ;;
	esac
	return 1
}
nvm_is_merged_node_version () {
	nvm_version_greater_than_or_equal_to "$1" v4.0.0
}
nvm_is_natural_num () {
	if [ -z "$1" ]
	then
		return 4
	fi
	case "$1" in
		(0) return 1 ;;
		(-*) return 3 ;;
		(*) [ "$1" -eq "$1" ] 2> /dev/null ;;
	esac
}
nvm_is_valid_version () {
	if nvm_validate_implicit_alias "${1-}" 2> /dev/null
	then
		return 0
	fi
	case "${1-}" in
		("$(nvm_iojs_prefix)" | "$(nvm_node_prefix)") return 0 ;;
		(*) local VERSION
			VERSION="$(nvm_strip_iojs_prefix "${1-}")" 
			nvm_version_greater_than_or_equal_to "${VERSION}" 0 ;;
	esac
}
nvm_is_version_installed () {
	if [ -z "${1-}" ]
	then
		return 1
	fi
	local NVM_NODE_BINARY
	NVM_NODE_BINARY='node' 
	if [ "_$(nvm_get_os)" = '_win' ]
	then
		NVM_NODE_BINARY='node.exe' 
	fi
	if [ -x "$(nvm_version_path "$1" 2>/dev/null)/bin/${NVM_NODE_BINARY}" ]
	then
		return 0
	fi
	return 1
}
nvm_is_zsh () {
	[ -n "${ZSH_VERSION-}" ]
}
nvm_list_aliases () {
	local ALIAS
	ALIAS="${1-}" 
	local NVM_CURRENT
	NVM_CURRENT="$(nvm_ls_current)" 
	local NVM_ALIAS_DIR
	NVM_ALIAS_DIR="$(nvm_alias_path)" 
	command mkdir -p "${NVM_ALIAS_DIR}/lts"
	if [ "${ALIAS}" != "${ALIAS#lts/}" ]
	then
		nvm_alias "${ALIAS}"
		return $?
	fi
	local NVM_HAS_COLORS
	NVM_HAS_COLORS=0 
	if nvm_has_colors
	then
		NVM_HAS_COLORS=1 
	fi
	nvm_is_zsh && unsetopt local_options nomatch
	(
		local ALIAS_PATH
		for ALIAS_PATH in "${NVM_ALIAS_DIR}/${ALIAS}"*
		do
			NVM_NO_COLORS="${NVM_NO_COLORS-}" NVM_HAS_COLORS="${NVM_HAS_COLORS}" NVM_CURRENT="${NVM_CURRENT}" nvm_print_alias_path "${NVM_ALIAS_DIR}" "${ALIAS_PATH}" &
		done
		wait
	) | command sort
	(
		local ALIAS_NAME
		for ALIAS_NAME in "$(nvm_node_prefix)" "stable" "unstable" "$(nvm_iojs_prefix)"
		do
			{
				if [ ! -f "${NVM_ALIAS_DIR}/${ALIAS_NAME}" ] && {
						[ -z "${ALIAS}" ] || [ "${ALIAS_NAME}" = "${ALIAS}" ]
					}
				then
					NVM_NO_COLORS="${NVM_NO_COLORS-}" NVM_HAS_COLORS="${NVM_HAS_COLORS}" NVM_CURRENT="${NVM_CURRENT}" nvm_print_default_alias "${ALIAS_NAME}"
				fi
			} &
		done
		wait
	) | command sort
	(
		local LTS_ALIAS
		for ALIAS_PATH in "${NVM_ALIAS_DIR}/lts/${ALIAS}"*
		do
			{
				LTS_ALIAS="$(NVM_NO_COLORS="${NVM_NO_COLORS-}" NVM_HAS_COLORS="${NVM_HAS_COLORS}" NVM_LTS=true nvm_print_alias_path "${NVM_ALIAS_DIR}" "${ALIAS_PATH}")" 
				if [ -n "${LTS_ALIAS}" ]
				then
					nvm_echo "${LTS_ALIAS}"
				fi
			} &
		done
		wait
	) | command sort
	return
}
nvm_ls () {
	local PATTERN
	PATTERN="${1-}" 
	case "${PATTERN}" in
		(*'#'* | *'
'*) local NVMRC_PATTERN
			if ! NVMRC_PATTERN="$(nvm_process_nvmrc_content "${PATTERN}" 2>/dev/null)" 
			then
				nvm_echo 'N/A'
				return 3
			fi
			PATTERN="${NVMRC_PATTERN}"  ;;
	esac
	local VERSIONS
	VERSIONS='' 
	if [ "${PATTERN}" = 'current' ]
	then
		nvm_ls_current
		return
	fi
	local NVM_IOJS_PREFIX
	NVM_IOJS_PREFIX="$(nvm_iojs_prefix)" 
	local NVM_NODE_PREFIX
	NVM_NODE_PREFIX="$(nvm_node_prefix)" 
	local NVM_VERSION_DIR_IOJS
	NVM_VERSION_DIR_IOJS="$(nvm_version_dir "${NVM_IOJS_PREFIX}")" 
	local NVM_VERSION_DIR_NEW
	NVM_VERSION_DIR_NEW="$(nvm_version_dir new)" 
	local NVM_VERSION_DIR_OLD
	NVM_VERSION_DIR_OLD="$(nvm_version_dir old)" 
	case "${PATTERN}" in
		("${NVM_IOJS_PREFIX}" | "${NVM_NODE_PREFIX}") PATTERN="${PATTERN}-"  ;;
		(*) local ALIAS_TARGET
			ALIAS_TARGET="$(nvm_resolve_alias "${PATTERN}" 2>/dev/null || nvm_echo)" 
			if [ "_${ALIAS_TARGET}" = '_system' ] && (
					nvm_has_system_iojs || nvm_has_system_node
				)
			then
				local SYSTEM_VERSION
				SYSTEM_VERSION="$(nvm deactivate >/dev/null 2>&1 && node -v 2>/dev/null)" 
				if [ -n "${SYSTEM_VERSION}" ]
				then
					nvm_echo "system ${SYSTEM_VERSION}"
				else
					nvm_echo "system"
				fi
				return
			fi
			if nvm_resolve_local_alias "${PATTERN}"
			then
				return
			fi
			PATTERN="$(nvm_ensure_version_prefix "${PATTERN}")"  ;;
	esac
	if [ "${PATTERN}" = 'N/A' ]
	then
		return
	fi
	local NVM_PATTERN_STARTS_WITH_V
	case $PATTERN in
		(v*) NVM_PATTERN_STARTS_WITH_V=true  ;;
		(*) NVM_PATTERN_STARTS_WITH_V=false  ;;
	esac
	if [ $NVM_PATTERN_STARTS_WITH_V = true ] && [ "_$(nvm_num_version_groups "${PATTERN}")" = "_3" ]
	then
		if nvm_is_version_installed "${PATTERN}"
		then
			VERSIONS="${PATTERN}" 
		elif nvm_is_version_installed "$(nvm_add_iojs_prefix "${PATTERN}")"
		then
			VERSIONS="$(nvm_add_iojs_prefix "${PATTERN}")" 
		fi
	else
		case "${PATTERN}" in
			("${NVM_IOJS_PREFIX}-" | "${NVM_NODE_PREFIX}-" | "system")  ;;
			(*) local NUM_VERSION_GROUPS
				NUM_VERSION_GROUPS="$(nvm_num_version_groups "${PATTERN}")" 
				if [ "${NUM_VERSION_GROUPS}" = "2" ] || [ "${NUM_VERSION_GROUPS}" = "1" ]
				then
					PATTERN="${PATTERN%.}." 
				fi ;;
		esac
		nvm_is_zsh && setopt local_options shwordsplit
		nvm_is_zsh && unsetopt local_options markdirs
		local NVM_DIRS_TO_SEARCH1
		NVM_DIRS_TO_SEARCH1='' 
		local NVM_DIRS_TO_SEARCH2
		NVM_DIRS_TO_SEARCH2='' 
		local NVM_DIRS_TO_SEARCH3
		NVM_DIRS_TO_SEARCH3='' 
		local NVM_ADD_SYSTEM
		NVM_ADD_SYSTEM=false 
		if nvm_is_iojs_version "${PATTERN}"
		then
			NVM_DIRS_TO_SEARCH1="${NVM_VERSION_DIR_IOJS}" 
			PATTERN="$(nvm_strip_iojs_prefix "${PATTERN}")" 
			if nvm_has_system_iojs
			then
				NVM_ADD_SYSTEM=true 
			fi
		elif [ "${PATTERN}" = "${NVM_NODE_PREFIX}-" ]
		then
			NVM_DIRS_TO_SEARCH1="${NVM_VERSION_DIR_OLD}" 
			NVM_DIRS_TO_SEARCH2="${NVM_VERSION_DIR_NEW}" 
			PATTERN='' 
			if nvm_has_system_node
			then
				NVM_ADD_SYSTEM=true 
			fi
		else
			NVM_DIRS_TO_SEARCH1="${NVM_VERSION_DIR_OLD}" 
			NVM_DIRS_TO_SEARCH2="${NVM_VERSION_DIR_NEW}" 
			NVM_DIRS_TO_SEARCH3="${NVM_VERSION_DIR_IOJS}" 
			if nvm_has_system_iojs || nvm_has_system_node
			then
				NVM_ADD_SYSTEM=true 
			fi
		fi
		if ! [ -d "${NVM_DIRS_TO_SEARCH1}" ] || ! (
				command ls -1qA "${NVM_DIRS_TO_SEARCH1}" | nvm_grep -q .
			)
		then
			NVM_DIRS_TO_SEARCH1='' 
		fi
		if ! [ -d "${NVM_DIRS_TO_SEARCH2}" ] || ! (
				command ls -1qA "${NVM_DIRS_TO_SEARCH2}" | nvm_grep -q .
			)
		then
			NVM_DIRS_TO_SEARCH2="${NVM_DIRS_TO_SEARCH1}" 
		fi
		if ! [ -d "${NVM_DIRS_TO_SEARCH3}" ] || ! (
				command ls -1qA "${NVM_DIRS_TO_SEARCH3}" | nvm_grep -q .
			)
		then
			NVM_DIRS_TO_SEARCH3="${NVM_DIRS_TO_SEARCH2}" 
		fi
		local SEARCH_PATTERN
		if [ -z "${PATTERN}" ]
		then
			PATTERN='v' 
			SEARCH_PATTERN='.*' 
		else
			SEARCH_PATTERN="$(nvm_echo "${PATTERN}" | command sed 's#\.#\\\.#g; s|#|\\#|g')" 
		fi
		if [ -n "${NVM_DIRS_TO_SEARCH1}${NVM_DIRS_TO_SEARCH2}${NVM_DIRS_TO_SEARCH3}" ]
		then
			VERSIONS="$(command find "${NVM_DIRS_TO_SEARCH1}"/* "${NVM_DIRS_TO_SEARCH2}"/* "${NVM_DIRS_TO_SEARCH3}"/* -name . -o -type d -prune -o -path "${PATTERN}*" \
        | command sed -e "
            s#${NVM_VERSION_DIR_IOJS}/#versions/${NVM_IOJS_PREFIX}/#;
            s#^${NVM_DIR}/##;
            \\#^[^v]# d;
            \\#^versions\$# d;
            s#^versions/##;
            s#^v#${NVM_NODE_PREFIX}/v#;
            \\#${SEARCH_PATTERN}# !d;
          " \
          -e 's#^\([^/]\{1,\}\)/\(.*\)$#\2.\1#;' \
        | command sort -t. -u -k 1.2,1n -k 2,2n -k 3,3n \
        | command sed -e 's#\(.*\)\.\([^\.]\{1,\}\)$#\2-\1#;' \
                      -e "s#^${NVM_NODE_PREFIX}-##;" \
      )" 
		fi
	fi
	if [ "${NVM_ADD_SYSTEM-}" = true ]
	then
		local SYSTEM_VERSION
		SYSTEM_VERSION="$(nvm deactivate >/dev/null 2>&1 && node -v 2>/dev/null)" 
		case "${PATTERN}" in
			('' | v) if [ -n "${SYSTEM_VERSION}" ]
				then
					VERSIONS="${VERSIONS}
system ${SYSTEM_VERSION}" 
				else
					VERSIONS="${VERSIONS}
system" 
				fi ;;
			(system) if [ -n "${SYSTEM_VERSION}" ]
				then
					VERSIONS="system ${SYSTEM_VERSION}" 
				else
					VERSIONS="system" 
				fi ;;
		esac
	fi
	if [ -z "${VERSIONS}" ]
	then
		nvm_echo 'N/A'
		return 3
	fi
	nvm_echo "${VERSIONS}"
}
nvm_ls_cached () {
	local PATTERN
	PATTERN="${1-}" 
	local NVM_CACHE_DIR
	NVM_CACHE_DIR="$(nvm_cache_dir)" 
	local NVM_OS
	NVM_OS="$(nvm_get_os)" 
	local NVM_ARCH
	NVM_ARCH="$(nvm_get_arch)" 
	local SUFFIX
	SUFFIX="${NVM_OS}-${NVM_ARCH}" 
	{
		if [ -d "${NVM_CACHE_DIR}/bin" ]
		then
			command ls -1 "${NVM_CACHE_DIR}/bin" | nvm_grep "^\\(node\\|iojs\\)-v[0-9][0-9.]*-${SUFFIX}\$" | command sed "s/-${SUFFIX}\$//"
		fi
		if [ -d "${NVM_CACHE_DIR}/src" ]
		then
			command ls -1 "${NVM_CACHE_DIR}/src" | nvm_grep "^\\(node\\|iojs\\)-v[0-9][0-9.]*\$"
		fi
	} | command sed 's/^node-//' | nvm_grep "$(nvm_ensure_version_prefix "${PATTERN}")" | command sort -t. -u -k 1.2,1n -k 2,2n -k 3,3n
}
nvm_ls_current () {
	local NVM_LS_CURRENT_NODE_PATH
	if ! NVM_LS_CURRENT_NODE_PATH="$(command which node 2>/dev/null)" 
	then
		nvm_echo 'none'
	elif nvm_tree_contains_path "$(nvm_version_dir iojs)" "${NVM_LS_CURRENT_NODE_PATH}"
	then
		nvm_add_iojs_prefix "$(iojs --version 2>/dev/null)"
	elif nvm_tree_contains_path "${NVM_DIR}" "${NVM_LS_CURRENT_NODE_PATH}"
	then
		local VERSION
		VERSION="$(node --version 2>/dev/null)" 
		if [ "${VERSION}" = "v0.6.21-pre" ]
		then
			nvm_echo 'v0.6.21'
		else
			nvm_echo "${VERSION:-none}"
		fi
	else
		nvm_echo 'system'
	fi
}
nvm_ls_remote () {
	local PATTERN
	PATTERN="${1-}" 
	if nvm_validate_implicit_alias "${PATTERN}" 2> /dev/null
	then
		local IMPLICIT
		IMPLICIT="$(nvm_print_implicit_alias remote "${PATTERN}")" 
		if [ -z "${IMPLICIT-}" ] || [ "${IMPLICIT}" = 'N/A' ]
		then
			nvm_echo "N/A"
			return 3
		fi
		PATTERN="$(NVM_LTS="${NVM_LTS-}" nvm_ls_remote "${IMPLICIT}" | command tail -1 | command awk '{ print $1 }')" 
	elif [ -n "${PATTERN}" ]
	then
		PATTERN="$(nvm_ensure_version_prefix "${PATTERN}")" 
	else
		PATTERN=".*" 
	fi
	NVM_LTS="${NVM_LTS-}" nvm_ls_remote_index_tab node std "${PATTERN}"
}
nvm_ls_remote_index_tab () {
	local LTS
	LTS="${NVM_LTS-}" 
	if [ "$#" -lt 3 ]
	then
		nvm_err 'not enough arguments'
		return 5
	fi
	local FLAVOR
	FLAVOR="${1-}" 
	local TYPE
	TYPE="${2-}" 
	local MIRROR
	MIRROR="$(nvm_get_mirror "${FLAVOR}" "${TYPE}")" 
	if [ -z "${MIRROR}" ]
	then
		return 3
	fi
	local PREFIX
	PREFIX='' 
	case "${FLAVOR}-${TYPE}" in
		(iojs-std) PREFIX="$(nvm_iojs_prefix)-"  ;;
		(node-std) PREFIX=''  ;;
		(iojs-*) nvm_err 'unknown type of io.js release'
			return 4 ;;
		(*) nvm_err 'unknown type of node.js release'
			return 4 ;;
	esac
	local SORT_COMMAND
	SORT_COMMAND='command sort' 
	case "${FLAVOR}" in
		(node) SORT_COMMAND='command sort -t. -u -k 1.2,1n -k 2,2n -k 3,3n'  ;;
	esac
	local PATTERN
	PATTERN="${3-}" 
	if [ "${PATTERN#"${PATTERN%?}"}" = '.' ]
	then
		PATTERN="${PATTERN%.}" 
	fi
	local VERSIONS
	if [ -n "${PATTERN}" ] && [ "${PATTERN}" != '*' ]
	then
		if [ "${FLAVOR}" = 'iojs' ]
		then
			PATTERN="$(nvm_ensure_version_prefix "$(nvm_strip_iojs_prefix "${PATTERN}")")" 
		else
			PATTERN="$(nvm_ensure_version_prefix "${PATTERN}")" 
		fi
	else
		unset PATTERN
	fi
	nvm_is_zsh && setopt local_options shwordsplit
	local VERSION_LIST
	VERSION_LIST="$(nvm_download -L -s "${MIRROR}/index.tab" -o - \
    | command sed "
        1d;
        s/^/${PREFIX}/;
      " \
  )" 
	local LTS_ALIAS
	local LTS_VERSION
	command mkdir -p "$(nvm_alias_path)/lts"
	{
		command awk '{
        if ($10 ~ /^\-?$/) { next }
        if (tolower($10) !~ /^[a-z0-9][a-z0-9._-]*$/) { next }
        if ($10 && !a[tolower($10)]++) {
          if (alias) { print alias, version }
          alias_name = "lts/" tolower($10)
          if (!alias) { print "lts/*", alias_name }
          alias = alias_name
          version = $1
        }
      }
      END {
        if (alias) {
          print alias, version
        }
      }' | while read -r LTS_ALIAS_LINE
		do
			LTS_ALIAS="${LTS_ALIAS_LINE%% *}" 
			LTS_VERSION="${LTS_ALIAS_LINE#* }" 
			nvm_make_alias "${LTS_ALIAS}" "${LTS_VERSION}" > /dev/null 2>&1
		done
	} <<EOF
$VERSION_LIST
EOF
	if [ -n "${LTS-}" ]
	then
		if ! LTS="$(nvm_normalize_lts "lts/${LTS}")" 
		then
			return $?
		fi
		LTS="${LTS#lts/}" 
	fi
	VERSIONS="$( { command awk -v lts="${LTS-}" '{
        if (!$1) { next }
        if (lts && $10 ~ /^\-?$/) { next }
        if (lts && lts != "*" && tolower($10) !~ tolower(lts)) { next }
        if ($10 !~ /^\-?$/) {
          if ($10 && $10 != prev) {
            print $1, $10, "*"
          } else {
            print $1, $10
          }
        } else {
          print $1
        }
        prev=$10;
      }' \
    | nvm_grep -w "${PATTERN:-.*}" \
    | $SORT_COMMAND; } << EOF
$VERSION_LIST
EOF
)" 
	if [ -z "${VERSIONS}" ]
	then
		nvm_echo 'N/A'
		return 3
	fi
	nvm_echo "${VERSIONS}"
}
nvm_ls_remote_iojs () {
	NVM_LTS="${NVM_LTS-}" nvm_ls_remote_index_tab iojs std "${1-}"
}
nvm_make_alias () {
	local ALIAS
	ALIAS="${1-}" 
	if [ -z "${ALIAS}" ]
	then
		nvm_err "an alias name is required"
		return 1
	fi
	local VERSION
	VERSION="${2-}" 
	if [ -z "${VERSION}" ]
	then
		nvm_err "an alias target version is required"
		return 2
	fi
	case "/${ALIAS}/" in
		(*/../*) nvm_err "invalid alias name: ${ALIAS}"
			return 3 ;;
	esac
	nvm_echo "${VERSION}" | tee "$(nvm_alias_path)/${ALIAS}" > /dev/null
}
nvm_match_version () {
	local NVM_IOJS_PREFIX
	NVM_IOJS_PREFIX="$(nvm_iojs_prefix)" 
	local PROVIDED_VERSION
	PROVIDED_VERSION="$1" 
	case "_${PROVIDED_VERSION}" in
		("_${NVM_IOJS_PREFIX}" | '_io.js') nvm_version "${NVM_IOJS_PREFIX}" ;;
		('_system') nvm_echo 'system' ;;
		(*) nvm_version "${PROVIDED_VERSION}" ;;
	esac
}
nvm_node_prefix () {
	nvm_echo 'node'
}
nvm_node_version_has_solaris_binary () {
	local NODE_VERSION
	NODE_VERSION="$1" 
	local STRIPPED_IOJS_VERSION
	STRIPPED_IOJS_VERSION="$(nvm_strip_iojs_prefix "${NODE_VERSION}")" 
	if [ "_${STRIPPED_IOJS_VERSION}" != "_${NODE_VERSION}" ]
	then
		return 1
	fi
	nvm_version_greater_than_or_equal_to "${NODE_VERSION}" v0.8.6 && ! nvm_version_greater_than_or_equal_to "${NODE_VERSION}" v1.0.0
}
nvm_normalize_lts () {
	local LTS
	LTS="${1-}" 
	case "${LTS}" in
		(lts/-[123456789] | lts/-[123456789][0123456789]*) local N
			N="$(echo "${LTS}" | cut -d '-' -f 2)" 
			N=$((N+1)) 
			if [ $? -ne 0 ]
			then
				nvm_echo "${LTS}"
				return 0
			fi
			local NVM_ALIAS_DIR
			NVM_ALIAS_DIR="$(nvm_alias_path)" 
			local RESULT
			RESULT="$(command ls "${NVM_ALIAS_DIR}/lts" | command tail -n "${N}" | command head -n 1)" 
			if [ "${RESULT}" != '*' ]
			then
				nvm_echo "lts/${RESULT}"
			else
				nvm_err 'That many LTS releases do not exist yet.'
				return 2
			fi ;;
		(*) case "${LTS}" in
				(lts/*) if [ "${LTS}" != "$(echo "${LTS}" | command tr '[:upper:]' '[:lower:]')" ]
					then
						nvm_err 'LTS names must be lowercase'
						return 3
					fi ;;
			esac
			nvm_echo "${LTS}" ;;
	esac
}
nvm_normalize_version () {
	command awk 'BEGIN {
    split(ARGV[1], a, /\./);
    printf "%d%06d%06d\n", a[1], a[2], a[3];
    exit;
  }' "${1#v}"
}
nvm_npm_global_modules () {
	local NPMLIST
	local VERSION
	VERSION="$1" 
	NPMLIST=$(nvm use "${VERSION}" >/dev/null && npm list -g --depth=0 2>/dev/null | command sed -e '1d' -e '/UNMET PEER DEPENDENCY/d') 
	local INSTALLS
	INSTALLS=$(nvm_echo "${NPMLIST}" | command sed -e '/ -> / d' -e '/\(empty\)/ d' -e 's/^.* \(.*@[^ ]*\).*/\1/' -e '/^npm@[^ ]*.*$/ d' -e '/^corepack@[^ ]*.*$/ d' | command xargs) 
	local LINKS
	LINKS="$(nvm_echo "${NPMLIST}" | command sed -n 's/.* -> \(.*\)/\1/ p')" 
	nvm_echo "${INSTALLS} //// ${LINKS}"
}
nvm_npmrc_bad_news_bears () {
	local NVM_NPMRC
	NVM_NPMRC="${1-}" 
	if [ -n "${NVM_NPMRC}" ] && [ -f "${NVM_NPMRC}" ] && nvm_grep -Ee '^(prefix|globalconfig) *=' < "${NVM_NPMRC}" > /dev/null
	then
		return 0
	fi
	return 1
}
nvm_num_version_groups () {
	local VERSION
	VERSION="${1-}" 
	VERSION="${VERSION#v}" 
	VERSION="${VERSION%.}" 
	if [ -z "${VERSION}" ]
	then
		nvm_echo "0"
		return
	fi
	local NVM_NUM_DOTS
	NVM_NUM_DOTS=$(nvm_echo "${VERSION}" | command sed -e 's/[^\.]//g') 
	local NVM_NUM_GROUPS
	NVM_NUM_GROUPS=".${NVM_NUM_DOTS}" 
	nvm_echo "${#NVM_NUM_GROUPS}"
}
nvm_nvmrc_invalid_msg () {
	local error_text
	error_text="invalid .nvmrc!
all non-commented content (anything after # is a comment) must be either:
  - a single bare nvm-recognized version-ish
  - or, multiple distinct key-value pairs, each key/value separated by a single equals sign (=)

additionally, a single bare nvm-recognized version-ish must be present (after stripping comments)." 
	local warn_text
	warn_text="non-commented content parsed:
${1}" 
	nvm_err "$(nvm_wrap_with_color_code 'r' "${error_text}")

$(nvm_wrap_with_color_code 'y' "${warn_text}")"
}
nvm_offline_version () {
	local PATTERN
	PATTERN="${1-}" 
	local VERSION
	VERSION="$(nvm_version "${PATTERN}")" 
	if [ "_${VERSION}" != '_N/A' ]
	then
		nvm_echo "${VERSION}"
		return 0
	fi
	VERSION="$(nvm_ls_cached "${PATTERN}" | command tail -1)" 
	if [ -n "${VERSION}" ]
	then
		nvm_echo "${VERSION}"
		return 0
	fi
	nvm_echo 'N/A'
	return 3
}
nvm_print_alias_path () {
	local NVM_ALIAS_DIR
	NVM_ALIAS_DIR="${1-}" 
	if [ -z "${NVM_ALIAS_DIR}" ]
	then
		nvm_err 'An alias dir is required.'
		return 1
	fi
	local ALIAS_PATH
	ALIAS_PATH="${2-}" 
	if [ -z "${ALIAS_PATH}" ]
	then
		nvm_err 'An alias path is required.'
		return 2
	fi
	local ALIAS
	ALIAS="${ALIAS_PATH##"${NVM_ALIAS_DIR}"\/}" 
	local DEST
	DEST="$(nvm_alias "${ALIAS}" 2>/dev/null)"  || :
	if [ -n "${DEST}" ]
	then
		NVM_NO_COLORS="${NVM_NO_COLORS-}" NVM_LTS="${NVM_LTS-}" DEFAULT=false nvm_print_formatted_alias "${ALIAS}" "${DEST}"
	fi
}
nvm_print_color_code () {
	case "${1-}" in
		('0') return 0 ;;
		('r') nvm_echo '0;31m' ;;
		('R') nvm_echo '1;31m' ;;
		('g') nvm_echo '0;32m' ;;
		('G') nvm_echo '1;32m' ;;
		('b') nvm_echo '0;34m' ;;
		('B') nvm_echo '1;34m' ;;
		('c') nvm_echo '0;36m' ;;
		('C') nvm_echo '1;36m' ;;
		('m') nvm_echo '0;35m' ;;
		('M') nvm_echo '1;35m' ;;
		('y') nvm_echo '0;33m' ;;
		('Y') nvm_echo '1;33m' ;;
		('k') nvm_echo '0;30m' ;;
		('K') nvm_echo '1;30m' ;;
		('e') nvm_echo '0;37m' ;;
		('W') nvm_echo '1;37m' ;;
		(*) nvm_err "Invalid color code: ${1-}"
			return 1 ;;
	esac
}
nvm_print_default_alias () {
	local ALIAS
	ALIAS="${1-}" 
	if [ -z "${ALIAS}" ]
	then
		nvm_err 'A default alias is required.'
		return 1
	fi
	local DEST
	DEST="$(nvm_print_implicit_alias local "${ALIAS}")" 
	if [ -n "${DEST}" ]
	then
		NVM_NO_COLORS="${NVM_NO_COLORS-}" DEFAULT=true nvm_print_formatted_alias "${ALIAS}" "${DEST}"
	fi
}
nvm_print_formatted_alias () {
	local ALIAS
	ALIAS="${1-}" 
	local DEST
	DEST="${2-}" 
	local VERSION
	VERSION="${3-}" 
	if [ -z "${VERSION}" ]
	then
		VERSION="$(nvm_version "${DEST}")"  || :
	fi
	local VERSION_FORMAT
	local ALIAS_FORMAT
	local DEST_FORMAT
	local INSTALLED_COLOR
	local SYSTEM_COLOR
	local CURRENT_COLOR
	local NOT_INSTALLED_COLOR
	local DEFAULT_COLOR
	local LTS_COLOR
	INSTALLED_COLOR=$(nvm_get_colors 1) 
	SYSTEM_COLOR=$(nvm_get_colors 2) 
	CURRENT_COLOR=$(nvm_get_colors 3) 
	NOT_INSTALLED_COLOR=$(nvm_get_colors 4) 
	DEFAULT_COLOR=$(nvm_get_colors 5) 
	LTS_COLOR=$(nvm_get_colors 6) 
	ALIAS_FORMAT='%s' 
	DEST_FORMAT='%s' 
	VERSION_FORMAT='%s' 
	local NEWLINE
	NEWLINE='\n' 
	if [ "_${DEFAULT}" = '_true' ]
	then
		NEWLINE=' (default)\n' 
	fi
	local ARROW
	ARROW='->' 
	if [ "${NVM_HAS_COLORS-}" = 1 ] || nvm_has_colors
	then
		ARROW='\033[0;90m->\033[0m' 
		if [ "_${DEFAULT}" = '_true' ]
		then
			NEWLINE=" \033[${DEFAULT_COLOR}(default)\033[0m\n" 
		fi
		if [ "_${VERSION}" = "_${NVM_CURRENT-}" ]
		then
			ALIAS_FORMAT="\033[${CURRENT_COLOR}%s\033[0m" 
			DEST_FORMAT="\033[${CURRENT_COLOR}%s\033[0m" 
			VERSION_FORMAT="\033[${CURRENT_COLOR}%s\033[0m" 
		elif nvm_is_version_installed "${VERSION}"
		then
			ALIAS_FORMAT="\033[${INSTALLED_COLOR}%s\033[0m" 
			DEST_FORMAT="\033[${INSTALLED_COLOR}%s\033[0m" 
			VERSION_FORMAT="\033[${INSTALLED_COLOR}%s\033[0m" 
		elif [ "${VERSION}" = '∞' ] || [ "${VERSION}" = 'N/A' ]
		then
			ALIAS_FORMAT="\033[${NOT_INSTALLED_COLOR}%s\033[0m" 
			DEST_FORMAT="\033[${NOT_INSTALLED_COLOR}%s\033[0m" 
			VERSION_FORMAT="\033[${NOT_INSTALLED_COLOR}%s\033[0m" 
		fi
		if [ "_${NVM_LTS-}" = '_true' ]
		then
			ALIAS_FORMAT="\033[${LTS_COLOR}%s\033[0m" 
		fi
		if [ "_${DEST%/*}" = "_lts" ]
		then
			DEST_FORMAT="\033[${LTS_COLOR}%s\033[0m" 
		fi
	elif [ "_${VERSION}" != '_∞' ] && [ "_${VERSION}" != '_N/A' ]
	then
		VERSION_FORMAT='%s *' 
	fi
	if [ "${DEST}" = "${VERSION}" ]
	then
		command printf -- "${ALIAS_FORMAT} ${ARROW} ${VERSION_FORMAT}${NEWLINE}" "${ALIAS}" "${DEST}"
	else
		command printf -- "${ALIAS_FORMAT} ${ARROW} ${DEST_FORMAT} (${ARROW} ${VERSION_FORMAT})${NEWLINE}" "${ALIAS}" "${DEST}" "${VERSION}"
	fi
}
nvm_print_implicit_alias () {
	if [ "_$1" != "_local" ] && [ "_$1" != "_remote" ]
	then
		nvm_err "nvm_print_implicit_alias must be specified with local or remote as the first argument."
		return 1
	fi
	local NVM_IMPLICIT
	NVM_IMPLICIT="$2" 
	if ! nvm_validate_implicit_alias "${NVM_IMPLICIT}"
	then
		return 2
	fi
	local NVM_IOJS_PREFIX
	NVM_IOJS_PREFIX="$(nvm_iojs_prefix)" 
	local NVM_NODE_PREFIX
	NVM_NODE_PREFIX="$(nvm_node_prefix)" 
	local NVM_COMMAND
	local NVM_ADD_PREFIX_COMMAND
	local LAST_TWO
	case "${NVM_IMPLICIT}" in
		("${NVM_IOJS_PREFIX}") NVM_COMMAND="nvm_ls_remote_iojs" 
			NVM_ADD_PREFIX_COMMAND="nvm_add_iojs_prefix" 
			if [ "_$1" = "_local" ]
			then
				NVM_COMMAND="nvm_ls ${NVM_IMPLICIT}" 
			fi
			nvm_is_zsh && setopt local_options shwordsplit
			local NVM_IOJS_VERSION
			local EXIT_CODE
			NVM_IOJS_VERSION="$(${NVM_COMMAND})"  && :
			EXIT_CODE="$?" 
			if [ "_${EXIT_CODE}" = "_0" ]
			then
				NVM_IOJS_VERSION="$(nvm_echo "${NVM_IOJS_VERSION}" | command sed "s/^${NVM_IMPLICIT}-//" | nvm_grep -e '^v' | command cut -c2- | command cut -d . -f 1,2 | uniq | command tail -1)" 
			fi
			if [ "_$NVM_IOJS_VERSION" = "_N/A" ]
			then
				nvm_echo 'N/A'
			else
				${NVM_ADD_PREFIX_COMMAND} "${NVM_IOJS_VERSION}"
			fi
			return $EXIT_CODE ;;
		("${NVM_NODE_PREFIX}") nvm_echo 'stable'
			return ;;
		(*) NVM_COMMAND="nvm_ls_remote" 
			if [ "_$1" = "_local" ]
			then
				NVM_COMMAND="nvm_ls node" 
			fi
			nvm_is_zsh && setopt local_options shwordsplit
			LAST_TWO=$($NVM_COMMAND | nvm_grep -e '^v' | command cut -c2- | command cut -d . -f 1,2 | uniq)  ;;
	esac
	local MINOR
	local STABLE
	local UNSTABLE
	local MOD
	local NORMALIZED_VERSION
	nvm_is_zsh && setopt local_options shwordsplit
	for MINOR in $LAST_TWO
	do
		NORMALIZED_VERSION="$(nvm_normalize_version "$MINOR")" 
		if [ "_0${NORMALIZED_VERSION#?}" != "_$NORMALIZED_VERSION" ]
		then
			STABLE="$MINOR" 
		else
			MOD="$(awk 'BEGIN { print int(ARGV[1] / 1000000) % 2 ; exit(0) }' "${NORMALIZED_VERSION}")" 
			if [ "${MOD}" -eq 0 ]
			then
				STABLE="${MINOR}" 
			elif [ "${MOD}" -eq 1 ]
			then
				UNSTABLE="${MINOR}" 
			fi
		fi
	done
	if [ "_$2" = '_stable' ]
	then
		nvm_echo "${STABLE}"
	elif [ "_$2" = '_unstable' ]
	then
		nvm_echo "${UNSTABLE:-"N/A"}"
	fi
}
nvm_print_npm_version () {
	if nvm_has "npm"
	then
		local NPM_VERSION
		NPM_VERSION="$(npm --version 2>/dev/null)" 
		if [ -n "${NPM_VERSION}" ]
		then
			command printf " (npm v${NPM_VERSION})"
		fi
	fi
}
nvm_print_versions () {
	local NVM_CURRENT
	NVM_CURRENT=$(nvm_ls_current) 
	local INSTALLED_COLOR
	local SYSTEM_COLOR
	local CURRENT_COLOR
	local NOT_INSTALLED_COLOR
	local DEFAULT_COLOR
	local LTS_COLOR
	local NVM_HAS_COLORS
	NVM_HAS_COLORS=0 
	INSTALLED_COLOR=$(nvm_get_colors 1) 
	SYSTEM_COLOR=$(nvm_get_colors 2) 
	CURRENT_COLOR=$(nvm_get_colors 3) 
	NOT_INSTALLED_COLOR=$(nvm_get_colors 4) 
	DEFAULT_COLOR=$(nvm_get_colors 5) 
	LTS_COLOR=$(nvm_get_colors 6) 
	if nvm_has_colors
	then
		NVM_HAS_COLORS=1 
	fi
	command awk -v remote_versions="$(printf '%s' "${1-}" | tr '\n' '|')" -v installed_versions="$(nvm_ls | tr '\n' '|')" -v current="$NVM_CURRENT" -v installed_color="$INSTALLED_COLOR" -v system_color="$SYSTEM_COLOR" -v current_color="$CURRENT_COLOR" -v default_color="$DEFAULT_COLOR" -v old_lts_color="$DEFAULT_COLOR" -v has_colors="$NVM_HAS_COLORS" '
function alen(arr, i, len) { len=0; for(i in arr) len++; return len; }
BEGIN {
  fmt_installed = has_colors ? (installed_color ? "\033[" installed_color "%15s\033[0m" : "%15s") : "%15s *";
  fmt_system = has_colors ? (system_color ? "\033[" system_color "%15s\033[0m" : "%15s") : "%15s *";
  fmt_current = has_colors ? (current_color ? "\033[" current_color "->%13s\033[0m" : "%15s") : "->%13s *";

  latest_lts_color = current_color;
  sub(/0;/, "1;", latest_lts_color);

  fmt_latest_lts = has_colors && latest_lts_color ? ("\033[" latest_lts_color " (Latest LTS: %s)\033[0m") : " (Latest LTS: %s)";
  fmt_old_lts = has_colors && old_lts_color ? ("\033[" old_lts_color " (LTS: %s)\033[0m") : " (LTS: %s)";
  fmt_system_target = has_colors && system_color ? (" (\033[" system_color "-> %s\033[0m)") : " (-> %s)";

  split(remote_versions, lines, "|");
  split(installed_versions, installed, "|");
  rows = alen(lines);

  for (n = 1; n <= rows; n++) {
    split(lines[n], fields, "[[:blank:]]+");
    cols = alen(fields);
    version = fields[1];
    is_installed = 0;

    for (i in installed) {
      if (version == installed[i]) {
        is_installed = 1;
        break;
      }
    }

    fmt_version = "%15s";
    if (version == current) {
      fmt_version = fmt_current;
    } else if (version == "system") {
      fmt_version = fmt_system;
    } else if (is_installed) {
      fmt_version = fmt_installed;
    }

    padding = (!has_colors && is_installed) ? "" : "  ";

    if (cols == 1) {
      formatted = sprintf(fmt_version, version);
    } else if (version == "system" && cols >= 2) {
      formatted = sprintf((fmt_version fmt_system_target), version, fields[2]);
    } else if (cols == 2) {
      formatted = sprintf((fmt_version padding fmt_old_lts), version, fields[2]);
    } else if (cols == 3 && fields[3] == "*") {
      formatted = sprintf((fmt_version padding fmt_latest_lts), version, fields[2]);
    }

    output[n] = formatted;
  }

  for (n = 1; n <= rows; n++) {
    print output[n]
  }

  exit
}'
}
nvm_process_nvmrc () {
	local NVMRC_PATH
	NVMRC_PATH="$1" 
	nvm_process_nvmrc_content "$(command cat "${NVMRC_PATH}")"
}
nvm_process_nvmrc_content () {
	local NVMRC_CONTENT
	NVMRC_CONTENT="${1-}" 
	local lines
	lines=$(nvm_echo "${NVMRC_CONTENT}" | command sed 's/#.*//' | command sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | nvm_grep -v '^$') 
	if [ -z "$lines" ]
	then
		nvm_nvmrc_invalid_msg "${lines}"
		return 1
	fi
	local keys
	keys='' 
	local values
	values='' 
	local unpaired_line
	unpaired_line='' 
	while IFS= read -r line
	do
		if [ -z "${line}" ]
		then
			continue
		elif [ -z "${line%%=*}" ]
		then
			if [ -n "${unpaired_line}" ]
			then
				nvm_nvmrc_invalid_msg "${lines}"
				return 1
			fi
			unpaired_line="${line}" 
		elif case "$line" in
				(*'='*) true ;;
				(*) false ;;
			esac
		then
			key="${line%%=*}" 
			value="${line#*=}" 
			key=$(nvm_echo "${key}" | command sed 's/^[[:space:]]*//;s/[[:space:]]*$//') 
			value=$(nvm_echo "${value}" | command sed 's/^[[:space:]]*//;s/[[:space:]]*$//') 
			if [ "${key}" = 'node' ]
			then
				nvm_nvmrc_invalid_msg "${lines}"
				return 1
			fi
			if nvm_echo "${keys}" | nvm_grep -q -E "(^| )${key}( |$)"
			then
				nvm_nvmrc_invalid_msg "${lines}"
				return 1
			fi
			keys="${keys} ${key}" 
			values="${values} ${value}" 
		else
			if [ -n "${unpaired_line}" ]
			then
				nvm_nvmrc_invalid_msg "${lines}"
				return 1
			fi
			unpaired_line="${line}" 
		fi
	done <<EOF
$lines
EOF
	if [ -z "${unpaired_line}" ]
	then
		nvm_nvmrc_invalid_msg "${lines}"
		return 1
	fi
	nvm_echo "${unpaired_line}"
}
nvm_process_parameters () {
	local NVM_AUTO_MODE
	NVM_AUTO_MODE='use' 
	while [ "$#" -ne 0 ]
	do
		case "$1" in
			(--install) NVM_AUTO_MODE='install'  ;;
			(--no-use) NVM_AUTO_MODE='none'  ;;
		esac
		shift
	done
	nvm_auto "${NVM_AUTO_MODE}"
}
nvm_rc_version () {
	local NVMRC_PATH
	NVMRC_PATH="$(nvm_find_nvmrc)" 
	if [ ! -e "${NVMRC_PATH}" ]
	then
		if [ "${NVM_SILENT:-0}" -ne 1 ]
		then
			nvm_err "No version provided and no .nvmrc file found"
		fi
		return 1
	fi
	local NVM_RC_VERSION
	if ! NVM_RC_VERSION="$(nvm_process_nvmrc "${NVMRC_PATH}")" 
	then
		return 1
	fi
	if [ -z "${NVM_RC_VERSION}" ]
	then
		if [ "${NVM_SILENT:-0}" -ne 1 ]
		then
			nvm_err "Warning: empty .nvmrc file found at \"${NVMRC_PATH}\""
		fi
		return 2
	fi
	if [ "${NVM_SILENT:-0}" -ne 1 ]
	then
		nvm_echo "Found '${NVMRC_PATH}' with version <${NVM_RC_VERSION}>"
	fi
	nvm_echo "${NVM_RC_VERSION}" >&3
}
nvm_remote_version () {
	local PATTERN
	PATTERN="${1-}" 
	local VERSION
	if nvm_validate_implicit_alias "${PATTERN}" 2> /dev/null
	then
		case "${PATTERN}" in
			("$(nvm_iojs_prefix)") VERSION="$(NVM_LTS="${NVM_LTS-}" nvm_ls_remote_iojs | command tail -1)"  && : ;;
			(*) VERSION="$(NVM_LTS="${NVM_LTS-}" nvm_ls_remote "${PATTERN}")"  && : ;;
		esac
	else
		VERSION="$(NVM_LTS="${NVM_LTS-}" nvm_remote_versions "${PATTERN}" | command tail -1)" 
	fi
	if [ -n "${PATTERN}" ] && [ "_${VERSION}" != "_N/A" ] && ! nvm_validate_implicit_alias "${PATTERN}" 2> /dev/null
	then
		local VERSION_NUM
		VERSION_NUM="$(nvm_echo "${VERSION}" | command awk '{print $1}')" 
		if ! nvm_echo "${VERSION_NUM}" | nvm_grep -q "${PATTERN}"
		then
			VERSION='N/A' 
		fi
	fi
	if [ -n "${NVM_VERSION_ONLY-}" ]
	then
		command awk 'BEGIN {
      n = split(ARGV[1], a);
      print a[1]
    }' "${VERSION}"
	else
		nvm_echo "${VERSION}"
	fi
	if [ "${VERSION}" = 'N/A' ]
	then
		return 3
	fi
}
nvm_remote_versions () {
	local NVM_IOJS_PREFIX
	NVM_IOJS_PREFIX="$(nvm_iojs_prefix)" 
	local NVM_NODE_PREFIX
	NVM_NODE_PREFIX="$(nvm_node_prefix)" 
	local PATTERN
	PATTERN="${1-}" 
	local NVM_FLAVOR
	if [ -n "${NVM_LTS-}" ]
	then
		NVM_FLAVOR="${NVM_NODE_PREFIX}" 
	fi
	case "${PATTERN}" in
		("${NVM_IOJS_PREFIX}" | "io.js") NVM_FLAVOR="${NVM_IOJS_PREFIX}" 
			unset PATTERN ;;
		("${NVM_NODE_PREFIX}") NVM_FLAVOR="${NVM_NODE_PREFIX}" 
			unset PATTERN ;;
	esac
	if nvm_validate_implicit_alias "${PATTERN-}" 2> /dev/null
	then
		nvm_err 'Implicit aliases are not supported in nvm_remote_versions.'
		return 1
	fi
	local NVM_LS_REMOTE_EXIT_CODE
	NVM_LS_REMOTE_EXIT_CODE=0 
	local NVM_LS_REMOTE_PRE_MERGED_OUTPUT
	NVM_LS_REMOTE_PRE_MERGED_OUTPUT='' 
	local NVM_LS_REMOTE_POST_MERGED_OUTPUT
	NVM_LS_REMOTE_POST_MERGED_OUTPUT='' 
	if [ -z "${NVM_FLAVOR-}" ] || [ "${NVM_FLAVOR-}" = "${NVM_NODE_PREFIX}" ]
	then
		local NVM_LS_REMOTE_OUTPUT
		NVM_LS_REMOTE_OUTPUT="$(NVM_LTS="${NVM_LTS-}" nvm_ls_remote "${PATTERN-}") "  && :
		NVM_LS_REMOTE_EXIT_CODE=$? 
		NVM_LS_REMOTE_PRE_MERGED_OUTPUT="${NVM_LS_REMOTE_OUTPUT%%v4\.0\.0*}" 
		NVM_LS_REMOTE_POST_MERGED_OUTPUT="${NVM_LS_REMOTE_OUTPUT#"$NVM_LS_REMOTE_PRE_MERGED_OUTPUT"}" 
	fi
	local NVM_LS_REMOTE_IOJS_EXIT_CODE
	NVM_LS_REMOTE_IOJS_EXIT_CODE=0 
	local NVM_LS_REMOTE_IOJS_OUTPUT
	NVM_LS_REMOTE_IOJS_OUTPUT='' 
	if [ -z "${NVM_LTS-}" ] && {
			[ -z "${NVM_FLAVOR-}" ] || [ "${NVM_FLAVOR-}" = "${NVM_IOJS_PREFIX}" ]
		}
	then
		NVM_LS_REMOTE_IOJS_OUTPUT=$(nvm_ls_remote_iojs "${PATTERN-}")  && :
		NVM_LS_REMOTE_IOJS_EXIT_CODE=$? 
	fi
	VERSIONS="$(nvm_echo "${NVM_LS_REMOTE_PRE_MERGED_OUTPUT}
${NVM_LS_REMOTE_IOJS_OUTPUT}
${NVM_LS_REMOTE_POST_MERGED_OUTPUT}" | nvm_grep -v "N/A" | command sed '/^ *$/d')" 
	if [ -z "${VERSIONS}" ]
	then
		nvm_echo 'N/A'
		return 3
	fi
	nvm_echo "${VERSIONS}" | command sed 's/ *$//g'
	if [ "${NVM_LS_REMOTE_EXIT_CODE}" != '0' ]
	then
		return "${NVM_LS_REMOTE_EXIT_CODE}"
	fi
	return "${NVM_LS_REMOTE_IOJS_EXIT_CODE}"
}
nvm_resolve_alias () {
	if [ -z "${1-}" ]
	then
		return 1
	fi
	local PATTERN
	PATTERN="${1-}" 
	local ALIAS
	ALIAS="${PATTERN}" 
	local ALIAS_TEMP
	local ALIAS_OUTPUT
	local SEEN_ALIASES
	SEEN_ALIASES="
${ALIAS}
" 
	while true
	do
		ALIAS_OUTPUT="$(nvm_alias "${ALIAS}" 2>/dev/null)"  || ALIAS_OUTPUT='' 
		ALIAS_TEMP="${ALIAS_OUTPUT%%
*}" 
		if [ -z "${ALIAS_TEMP}" ]
		then
			break
		fi
		case "${SEEN_ALIASES}" in
			(*"
${ALIAS_TEMP}
"*) ALIAS="∞" 
				break ;;
		esac
		SEEN_ALIASES="${SEEN_ALIASES}${ALIAS_TEMP}
" 
		ALIAS="${ALIAS_TEMP}" 
	done
	if [ -n "${ALIAS}" ] && [ "_${ALIAS}" != "_${PATTERN}" ]
	then
		local NVM_IOJS_PREFIX
		NVM_IOJS_PREFIX="$(nvm_iojs_prefix)" 
		local NVM_NODE_PREFIX
		NVM_NODE_PREFIX="$(nvm_node_prefix)" 
		case "${ALIAS}" in
			('∞' | "${NVM_IOJS_PREFIX}" | "${NVM_IOJS_PREFIX}-" | "${NVM_NODE_PREFIX}") nvm_echo "${ALIAS}" ;;
			(*) nvm_ensure_version_prefix "${ALIAS}" ;;
		esac
		return 0
	fi
	if nvm_validate_implicit_alias "${PATTERN}" 2> /dev/null
	then
		local IMPLICIT
		IMPLICIT="$(nvm_print_implicit_alias local "${PATTERN}" 2>/dev/null)" 
		if [ -n "${IMPLICIT}" ]
		then
			nvm_ensure_version_prefix "${IMPLICIT}"
		fi
	fi
	return 2
}
nvm_resolve_local_alias () {
	if [ -z "${1-}" ]
	then
		return 1
	fi
	local VERSION
	local EXIT_CODE
	VERSION="$(nvm_resolve_alias "${1-}")" 
	EXIT_CODE=$? 
	if [ -z "${VERSION}" ]
	then
		return $EXIT_CODE
	fi
	if [ "_${VERSION}" != '_∞' ]
	then
		nvm_version "${VERSION}"
	else
		nvm_echo "${VERSION}"
	fi
}
nvm_sanitize_auth_header () {
	nvm_echo "$1" | command sed 's/[^a-zA-Z0-9 :_.+/=-]//g'
}
nvm_sanitize_path () {
	local SANITIZED_PATH
	SANITIZED_PATH="${1-}" 
	if [ "_${SANITIZED_PATH}" != "_${NVM_DIR}" ]
	then
		SANITIZED_PATH="$(nvm_echo "${SANITIZED_PATH}" | command sed -e "s#${NVM_DIR}#\${NVM_DIR}#g")" 
	fi
	if [ "_${SANITIZED_PATH}" != "_${HOME}" ]
	then
		SANITIZED_PATH="$(nvm_echo "${SANITIZED_PATH}" | command sed -e "s#${HOME}#\${HOME}#g")" 
	fi
	nvm_echo "${SANITIZED_PATH}"
}
nvm_set_colors () {
	if [ "${#1}" -eq 5 ] && nvm_echo "$1" | nvm_grep -E "^[rRgGbBcCyYmMkKeW]{1,}$" > /dev/null
	then
		local INSTALLED_COLOR
		local LTS_AND_SYSTEM_COLOR
		local CURRENT_COLOR
		local NOT_INSTALLED_COLOR
		local DEFAULT_COLOR
		INSTALLED_COLOR="$(echo "$1" | awk '{ print substr($0, 1, 1); }')" 
		LTS_AND_SYSTEM_COLOR="$(echo "$1" | awk '{ print substr($0, 2, 1); }')" 
		CURRENT_COLOR="$(echo "$1" | awk '{ print substr($0, 3, 1); }')" 
		NOT_INSTALLED_COLOR="$(echo "$1" | awk '{ print substr($0, 4, 1); }')" 
		DEFAULT_COLOR="$(echo "$1" | awk '{ print substr($0, 5, 1); }')" 
		if ! nvm_has_colors
		then
			nvm_echo "Setting colors to: ${INSTALLED_COLOR} ${LTS_AND_SYSTEM_COLOR} ${CURRENT_COLOR} ${NOT_INSTALLED_COLOR} ${DEFAULT_COLOR}"
			nvm_echo "WARNING: Colors may not display because they are not supported in this shell."
		else
			nvm_echo_with_colors "Setting colors to: $(nvm_wrap_with_color_code "${INSTALLED_COLOR}" "${INSTALLED_COLOR}")$(nvm_wrap_with_color_code "${LTS_AND_SYSTEM_COLOR}" "${LTS_AND_SYSTEM_COLOR}")$(nvm_wrap_with_color_code "${CURRENT_COLOR}" "${CURRENT_COLOR}")$(nvm_wrap_with_color_code "${NOT_INSTALLED_COLOR}" "${NOT_INSTALLED_COLOR}")$(nvm_wrap_with_color_code "${DEFAULT_COLOR}" "${DEFAULT_COLOR}")"
		fi
		export NVM_COLORS="$1" 
	else
		return 17
	fi
}
nvm_stdout_is_terminal () {
	[ -t 1 ]
}
nvm_strip_iojs_prefix () {
	local NVM_IOJS_PREFIX
	NVM_IOJS_PREFIX="$(nvm_iojs_prefix)" 
	case "${1-}" in
		("${NVM_IOJS_PREFIX}") nvm_echo ;;
		(*) nvm_echo "${1#"${NVM_IOJS_PREFIX}"-}" ;;
	esac
}
nvm_strip_path () {
	if [ -z "${NVM_DIR-}" ]
	then
		nvm_err '${NVM_DIR} not set!'
		return 1
	fi
	local RESULT
	RESULT="$(command printf %s "${1-}" | command awk -v NVM_DIR="${NVM_DIR}" -v RS=: '
  index($0, NVM_DIR) == 1 {
    path = substr($0, length(NVM_DIR) + 1)
    if (path ~ "^(/versions/[^/]*)?/[^/]*'"${2-}"'.*$") { next }
  }
  { printf "%s%s", sep, $0; sep=RS }')" 
	case "${1-}" in
		(*:) command printf '%s:' "${RESULT}" ;;
		(*) command printf '%s' "${RESULT}" ;;
	esac
}
nvm_supports_xz () {
	if [ -z "${1-}" ]
	then
		return 1
	fi
	local NVM_OS
	NVM_OS="$(nvm_get_os)" 
	if [ "_${NVM_OS}" = '_darwin' ]
	then
		local MACOS_VERSION
		MACOS_VERSION="$(sw_vers -productVersion)" 
		if nvm_version_greater "10.9.0" "${MACOS_VERSION}"
		then
			return 1
		fi
	elif [ "_${NVM_OS}" = '_freebsd' ]
	then
		if ! [ -e '/usr/lib/liblzma.so' ]
		then
			return 1
		fi
	else
		if ! command which xz > /dev/null 2>&1
		then
			return 1
		fi
	fi
	if nvm_is_merged_node_version "${1}"
	then
		return 0
	fi
	if nvm_version_greater_than_or_equal_to "${1}" "0.12.10" && nvm_version_greater "0.13.0" "${1}"
	then
		return 0
	fi
	if nvm_version_greater_than_or_equal_to "${1}" "0.10.42" && nvm_version_greater "0.11.0" "${1}"
	then
		return 0
	fi
	case "${NVM_OS}" in
		(darwin) nvm_version_greater_than_or_equal_to "${1}" "2.3.2" ;;
		(*) nvm_version_greater_than_or_equal_to "${1}" "1.0.0" ;;
	esac
	return $?
}
nvm_tree_contains_path () {
	local tree
	tree="${1-}" 
	local node_path
	node_path="${2-}" 
	if [ "@${tree}@" = "@@" ] || [ "@${node_path}@" = "@@" ]
	then
		nvm_err "both the tree and the node path are required"
		return 2
	fi
	local previous_pathdir
	previous_pathdir="${node_path}" 
	local pathdir
	pathdir=$(dirname "${previous_pathdir}") 
	while [ "${pathdir}" != '' ] && [ "${pathdir}" != '.' ] && [ "${pathdir}" != '/' ] && [ "${pathdir}" != "${tree}" ] && [ "${pathdir}" != "${previous_pathdir}" ]
	do
		previous_pathdir="${pathdir}" 
		pathdir=$(dirname "${previous_pathdir}") 
	done
	[ "${pathdir}" = "${tree}" ]
}
nvm_use_if_needed () {
	if [ "_${1-}" = "_$(nvm_ls_current)" ]
	then
		return
	fi
	nvm use "$@"
}
nvm_validate_implicit_alias () {
	local NVM_IOJS_PREFIX
	NVM_IOJS_PREFIX="$(nvm_iojs_prefix)" 
	local NVM_NODE_PREFIX
	NVM_NODE_PREFIX="$(nvm_node_prefix)" 
	case "$1" in
		("stable" | "unstable" | "${NVM_IOJS_PREFIX}" | "${NVM_NODE_PREFIX}") return ;;
		(*) nvm_err "Only implicit aliases 'stable', 'unstable', '${NVM_IOJS_PREFIX}', and '${NVM_NODE_PREFIX}' are supported."
			return 1 ;;
	esac
}
nvm_version () {
	local PATTERN
	PATTERN="${1-}" 
	local VERSION
	if [ -z "${PATTERN}" ]
	then
		PATTERN='current' 
	fi
	if [ "${PATTERN}" = "current" ]
	then
		nvm_ls_current
		return $?
	fi
	local NVM_NODE_PREFIX
	NVM_NODE_PREFIX="$(nvm_node_prefix)" 
	case "_${PATTERN}" in
		("_${NVM_NODE_PREFIX}" | "_${NVM_NODE_PREFIX}-") PATTERN="stable"  ;;
	esac
	VERSION="$(nvm_ls "${PATTERN}" | command tail -1)" 
	case "${VERSION}" in
		(system[[:blank:]]*) VERSION='system'  ;;
	esac
	if [ -z "${VERSION}" ] || [ "_${VERSION}" = "_N/A" ]
	then
		nvm_echo "N/A"
		return 3
	fi
	nvm_echo "${VERSION}"
}
nvm_version_dir () {
	local NVM_WHICH_DIR
	NVM_WHICH_DIR="${1-}" 
	if [ -z "${NVM_WHICH_DIR}" ] || [ "${NVM_WHICH_DIR}" = "new" ]
	then
		nvm_echo "${NVM_DIR}/versions/node"
	elif [ "_${NVM_WHICH_DIR}" = "_iojs" ]
	then
		nvm_echo "${NVM_DIR}/versions/io.js"
	elif [ "_${NVM_WHICH_DIR}" = "_old" ]
	then
		nvm_echo "${NVM_DIR}"
	else
		nvm_err 'unknown version dir'
		return 3
	fi
}
nvm_version_greater () {
	command awk 'BEGIN {
    if (ARGV[1] == "" || ARGV[2] == "") exit(1)
    split(ARGV[1], a, /\./);
    split(ARGV[2], b, /\./);
    for (i=1; i<=3; i++) {
      if (a[i] && a[i] !~ /^[0-9]+$/) exit(2);
      if (b[i] && b[i] !~ /^[0-9]+$/) { exit(0); }
      if (a[i] < b[i]) exit(3);
      else if (a[i] > b[i]) exit(0);
    }
    exit(4)
  }' "${1#v}" "${2#v}"
}
nvm_version_greater_than_or_equal_to () {
	command awk 'BEGIN {
    if (ARGV[1] == "" || ARGV[2] == "") exit(1)
    split(ARGV[1], a, /\./);
    split(ARGV[2], b, /\./);
    for (i=1; i<=3; i++) {
      if (a[i] && a[i] !~ /^[0-9]+$/) exit(2);
      if (a[i] < b[i]) exit(3);
      else if (a[i] > b[i]) exit(0);
    }
    exit(0)
  }' "${1#v}" "${2#v}"
}
nvm_version_path () {
	local VERSION
	VERSION="${1-}" 
	if [ -z "${VERSION}" ]
	then
		nvm_err 'version is required'
		return 3
	elif nvm_is_iojs_version "${VERSION}"
	then
		nvm_echo "$(nvm_version_dir iojs)/$(nvm_strip_iojs_prefix "${VERSION}")"
	elif nvm_version_greater 0.12.0 "${VERSION}"
	then
		nvm_echo "$(nvm_version_dir old)/${VERSION}"
	else
		nvm_echo "$(nvm_version_dir new)/${VERSION}"
	fi
}
nvm_wrap_with_color_code () {
	local CODE
	CODE="$(nvm_print_color_code "${1}" 2>/dev/null ||:)" 
	local TEXT
	TEXT="${2-}" 
	if nvm_has_colors && [ -n "${CODE}" ]
	then
		nvm_echo_with_colors "\033[${CODE}${TEXT}\033[0m"
	else
		nvm_echo "${TEXT}"
	fi
}
nvm_write_nvmrc () {
	local VERSION_STRING
	VERSION_STRING=$(nvm_version "${1-}") 
	if [ "${VERSION_STRING}" = '∞' ] || [ "${VERSION_STRING}" = 'N/A' ]
	then
		return 1
	fi
	echo "${VERSION_STRING}" | tee "$PWD"/.nvmrc > /dev/null || {
		if [ "${NVM_SILENT:-0}" -ne 1 ]
		then
			nvm_err "Warning: Unable to write version number ($VERSION_STRING) to .nvmrc"
		fi
		return 3
	}
	if [ "${NVM_SILENT:-0}" -ne 1 ]
	then
		nvm_echo "Wrote version number ($VERSION_STRING) to .nvmrc"
	fi
}
nvmpick () {
	local version
	version=$(nvm list | grep -v 'default' | sed 's/[->*]//g' | awk '{print $1}' \
    | fzf --height 40% --prompt "Node Version> ")  || return
	nvm use "$version"
}
openfiles () {
	local pid="${1}" 
	if [[ -z "$pid" ]]
	then
		echo "Usage: openfiles <pid>"
		return 1
	fi
	lsof -p "$pid"
}
openrouter_fzf () {
	if ! command -v fzf &> /dev/null
	then
		echo "Error: fzf is not installed. Install with: brew install fzf (macOS) or dnf install fzf (Linux)"
		return 1
	fi
	if ! command -v jq &> /dev/null
	then
		echo "Error: jq is not installed. Install with: brew install jq (macOS) or dnf install jq (Linux)"
		return 1
	fi
	if [[ -z "$OPENROUTER_API_KEY" ]]
	then
		echo "Error: OPENROUTER_API_KEY environment variable is not set"
		return 1
	fi
	echo "Fetching models from OpenRouter..."
	local models
	models=$(curl -s https://openrouter.ai/api/v1/models \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" | jq -r '.data[].id' | sort) 
	if [[ -z "$models" ]]
	then
		echo "Error: Failed to fetch models from OpenRouter"
		return 1
	fi
	local selected_model
	selected_model=$(echo "$models" | fzf \
        --prompt="Select OpenRouter model: " \
        --header="Use arrow keys to navigate, Enter to select" \
        --height=40% \
        --border) 
	if [[ -z "$selected_model" ]]
	then
		echo "No model selected"
		return 1
	fi
	local tiers=("all" "sonnet" "opus" "haiku" "fable") 
	local selected_tier
	selected_tier=$(printf '%s\n' "${tiers[@]}" | fzf \
        --prompt="Select model tier: " \
        --header="Which Claude tier should use $selected_model?" \
        --height=20% \
        --border) 
	if [[ -z "$selected_tier" ]]
	then
		echo "No tier selected"
		return 1
	fi
	if [[ "$selected_tier" == "all" ]]
	then
		openrouter_set_model sonnet "$selected_model"
		openrouter_set_model opus "$selected_model"
		openrouter_set_model haiku "$selected_model"
		openrouter_set_model fable "$selected_model"
	else
		openrouter_set_model "$selected_tier" "$selected_model"
	fi
}
openrouter_off () {
	unset ANTHROPIC_BASE_URL
	unset ANTHROPIC_AUTH_TOKEN
	unset ANTHROPIC_API_KEY
	unset ANTHROPIC_DEFAULT_SONNET_MODEL
	unset ANTHROPIC_DEFAULT_OPUS_MODEL
	unset ANTHROPIC_DEFAULT_HAIKU_MODEL
	unset ANTHROPIC_DEFAULT_FABLE_MODEL
	unset CLAUDE_CODE_SUBAGENT_MODEL
	unset CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY
	echo "OpenRouter mode disabled"
}
openrouter_on () {
	if [[ -z "$OPENROUTER_API_KEY" ]]
	then
		echo "Error: OPENROUTER_API_KEY environment variable is not set"
		echo "Please set it with: export OPENROUTER_API_KEY='your-api-key'"
		return 1
	fi
	bedrock_off > /dev/null
	deepseek_off > /dev/null
	export ANTHROPIC_BASE_URL="${OPENROUTER_ANTHROPIC_BASE_URL_ORIG}" 
	export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY" 
	export ANTHROPIC_API_KEY="${OPENROUTER_ANTHROPIC_API_KEY_ORIG}" 
	[[ -n "$OPENROUTER_DEFAULT_SONNET_MODEL_ORIG" ]] && export ANTHROPIC_DEFAULT_SONNET_MODEL="${OPENROUTER_DEFAULT_SONNET_MODEL_ORIG}" 
	[[ -n "$OPENROUTER_DEFAULT_OPUS_MODEL_ORIG" ]] && export ANTHROPIC_DEFAULT_OPUS_MODEL="${OPENROUTER_DEFAULT_OPUS_MODEL_ORIG}" 
	[[ -n "$OPENROUTER_DEFAULT_HAIKU_MODEL_ORIG" ]] && export ANTHROPIC_DEFAULT_HAIKU_MODEL="${OPENROUTER_DEFAULT_HAIKU_MODEL_ORIG}" 
	[[ -n "$OPENROUTER_DEFAULT_FABLE_MODEL_ORIG" ]] && export ANTHROPIC_DEFAULT_FABLE_MODEL="${OPENROUTER_DEFAULT_FABLE_MODEL_ORIG}" 
	[[ -n "$OPENROUTER_SUBAGENT_MODEL_ORIG" ]] && export CLAUDE_CODE_SUBAGENT_MODEL="${OPENROUTER_SUBAGENT_MODEL_ORIG}" 
	[[ -n "$OPENROUTER_GATEWAY_MODEL_DISCOVERY_ORIG" ]] && export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY="${OPENROUTER_GATEWAY_MODEL_DISCOVERY_ORIG}" 
	echo "OpenRouter mode enabled"
}
openrouter_set_model () {
	local model_tier="$1" 
	local model_name="$2" 
	if [[ -z "$model_tier" || -z "$model_name" ]]
	then
		echo "Usage: openrouter_set_model <sonnet|opus|haiku|fable> <model-name>"
		echo ""
		echo "Examples:"
		echo "  openrouter_set_model sonnet ~anthropic/claude-sonnet-latest"
		echo "  openrouter_set_model opus anthropic/claude-opus-5"
		echo "  openrouter_set_model haiku openai/gpt-5-mini"
		echo ""
		echo "You can also use OpenRouter presets:"
		echo "  openrouter_set_model sonnet @preset/your-preset-slug"
		echo ""
		echo "To clear a model override:"
		echo "  openrouter_set_model sonnet ''"
		return 1
	fi
	case "$model_tier" in
		(sonnet) OPENROUTER_DEFAULT_SONNET_MODEL_ORIG="$model_name" 
			echo "Sonnet model set to: $model_name" ;;
		(opus) OPENROUTER_DEFAULT_OPUS_MODEL_ORIG="$model_name" 
			echo "Opus model set to: $model_name" ;;
		(haiku) OPENROUTER_DEFAULT_HAIKU_MODEL_ORIG="$model_name" 
			echo "Haiku model set to: $model_name" ;;
		(fable) OPENROUTER_DEFAULT_FABLE_MODEL_ORIG="$model_name" 
			echo "Fable model set to: $model_name" ;;
		(*) echo "Error: Invalid model tier. Must be one of: sonnet, opus, haiku, fable"
			return 1 ;;
	esac
	echo "Run 'openrouter_on' to apply changes"
}
p10k () {
	[[ $# != 1 || $1 != finalize ]] || {
		p10k-instant-prompt-finalize
		return 0
	}
	eval "$__p9k_intro_no_reply"
	if (( !ARGC ))
	then
		print -rP -- $__p9k_p10k_usage >&2
		return 1
	fi
	case $1 in
		(segment) local REPLY
			local -a reply
			shift
			local -i OPTIND
			local OPTARG opt state bg=0 fg icon cond text ref=0 expand=0 
			while getopts ':s:b:f:i:c:t:reh' opt
			do
				case $opt in
					(s) state=$OPTARG  ;;
					(b) bg=$OPTARG  ;;
					(f) fg=$OPTARG  ;;
					(i) icon=$OPTARG  ;;
					(c) cond=${OPTARG:-'${:-}'}  ;;
					(t) text=$OPTARG  ;;
					(r) ref=1  ;;
					(e) expand=1  ;;
					(+r) ref=0  ;;
					(+e) expand=0  ;;
					(h) print -rP -- $__p9k_p10k_segment_usage
						return 0 ;;
					(?) print -rP -- $__p9k_p10k_segment_usage >&2
						return 1 ;;
				esac
			done
			if (( OPTIND <= ARGC ))
			then
				print -rP -- $__p9k_p10k_segment_usage >&2
				return 1
			fi
			if [[ -z $_p9k__prompt_side ]]
			then
				print -rP -- "%1F[ERROR]%f %Bp10k segment%b: can be called only during prompt rendering." >&2
				if (( !ARGC ))
				then
					print -rP -- ""
					print -rP -- "For help, type:" >&2
					print -rP -- ""
					print -rP -- "  %2Fp10k%f %Bhelp%b %Bsegment%b" >&2
				fi
				return 1
			fi
			(( ref )) || icon=$'\1'$icon 
			typeset -i _p9k__has_upglob
			"_p9k_${_p9k__prompt_side}_prompt_segment" "prompt_${_p9k__segment_name}${state:+_${${(U)state}//İ/I}}" "$bg" "${fg:-$_p9k_color1}" "$icon" "$expand" "$cond" "$text"
			return 0 ;;
		(display) if (( ARGC == 1 ))
			then
				print -rP -- $__p9k_p10k_display_usage >&2
				return 1
			fi
			shift
			local -i k dump
			local opt prev new pair list name var
			while getopts ':har' opt
			do
				case $opt in
					(r) if (( __p9k_reset_state > 0 ))
						then
							__p9k_reset_state=2 
						else
							__p9k_reset_state=-1 
						fi ;;
					(a) dump=1  ;;
					(h) print -rP -- $__p9k_p10k_display_usage
						return 0 ;;
					(?) print -rP -- $__p9k_p10k_display_usage >&2
						return 1 ;;
				esac
			done
			if (( dump ))
			then
				reply=() 
				shift $((OPTIND-1))
				(( ARGC )) || set -- '*'
				for opt
				do
					for k in ${(u@)_p9k_display_k[(I)$opt]:/(#m)*/$_p9k_display_k[$MATCH]}
					do
						reply+=($_p9k__display_v[k,k+1]) 
					done
				done
				if (( __p9k_reset_state == -1 ))
				then
					_p9k_reset_prompt
				fi
				return 0
			fi
			local REPLY
			local -a reply
			for opt in "${@:$OPTIND}"
			do
				pair=(${(s:=:)opt}) 
				list=(${(s:,:)${pair[2]}}) 
				if [[ ${(b)pair[1]} == $pair[1] ]]
				then
					local ks=($_p9k_display_k[$pair[1]]) 
				else
					local ks=(${(u@)_p9k_display_k[(I)$pair[1]]:/(#m)*/$_p9k_display_k[$MATCH]}) 
				fi
				for k in $ks
				do
					if (( $#list == 1 ))
					then
						[[ $_p9k__display_v[k+1] == $list[1] ]] && continue
						new=$list[1] 
					else
						new=${list[list[(I)$_p9k__display_v[k+1]]+1]:-$list[1]} 
						[[ $_p9k__display_v[k+1] == $new ]] && continue
					fi
					_p9k__display_v[k+1]=$new 
					name=$_p9k__display_v[k] 
					if [[ $name == (empty_line|ruler) ]]
					then
						var=_p9k__${name}_i 
						[[ $new == show ]] && unset $var || typeset -gi $var=3
					elif [[ $name == (#b)(<->)(*) ]]
					then
						var=_p9k__${match[1]}${${${${match[2]//\/}/#left/l}/#right/r}/#gap/g} 
						[[ $new == hide ]] && typeset -g $var= || unset $var
					fi
					if (( __p9k_reset_state > 0 ))
					then
						__p9k_reset_state=2 
					else
						__p9k_reset_state=-1 
					fi
				done
			done
			if (( __p9k_reset_state == -1 ))
			then
				_p9k_reset_prompt
			fi ;;
		(configure) if (( ARGC > 1 ))
			then
				print -rP -- $__p9k_p10k_configure_usage >&2
				return 1
			fi
			local REPLY
			local -a reply
			p9k_configure "$@" || return ;;
		(reload) if (( ARGC > 1 ))
			then
				print -rP -- $__p9k_p10k_reload_usage >&2
				return 1
			fi
			(( $+_p9k__force_must_init )) || return 0
			_p9k__force_must_init=1  ;;
		(help) local var=__p9k_p10k_$2_usage 
			if (( $+parameters[$var] ))
			then
				print -rP -- ${(P)var}
				return 0
			elif (( ARGC == 1 ))
			then
				print -rP -- $__p9k_p10k_usage
				return 0
			else
				print -rP -- $__p9k_p10k_usage >&2
				return 1
			fi ;;
		(finalize) print -rP -- $__p9k_p10k_finalize_usage >&2
			return 1 ;;
		(clear-instant-prompt) if (( $+__p9k_instant_prompt_active ))
			then
				_p9k_clear_instant_prompt
				unset __p9k_instant_prompt_active
			fi
			return 0 ;;
		(*) print -rP -- $__p9k_p10k_usage >&2
			return 1 ;;
	esac
}
p10k-instant-prompt-finalize () {
	unsetopt local_options
	(( ${+__p9k_instant_prompt_active} )) && unsetopt prompt_cr prompt_sp || setopt prompt_cr prompt_sp
}
p9k_configure () {
	eval "$__p9k_intro"
	_p9k_can_configure || return
	(
		set -- -f
		builtin source $__p9k_root_dir/internal/wizard.zsh
	)
	local ret=$? 
	case $ret in
		(0) builtin source $__p9k_cfg_path
			_p9k__force_must_init=1  ;;
		(69) return 0 ;;
		(*) return $ret ;;
	esac
}
p9k_prompt_segment () {
	p10k segment "$@"
}
perfcheck () {
	batcat <<'EOF'

===================  SYSTEM PERFORMANCE CHECK  ===================

EOF
	echo "=== CPU Info ==="
	if command -v lscpu > /dev/null 2>&1
	then
		lscpu | grep -E "Model name|CPU\(s\)|Thread|MHz"
	else
		batcat /proc/cpuinfo | grep -E "model name|cpu cores" | head -2
	fi
	echo ""
	echo "=== Memory Usage ==="
	free -h
	echo ""
	echo "=== Load Average ==="
	uptime
	echo ""
	echo "=== Top Processes (CPU) ==="
	ps aux --sort=-%cpu | head -6
	echo ""
	echo "=== Top Processes (Memory) ==="
	ps aux --sort=-%mem | head -6
	echo ""
	echo "=== Disk Usage ==="
	df -h / | tail -1
	echo ""
	echo "=== Disk I/O (last 5 seconds) ==="
	if command -v iostat > /dev/null 2>&1
	then
		iostat -x 1 5 | tail -20
	else
		echo "iostat not installed (dnf install sysstat)"
	fi
	echo ""
	echo "================================================================"
}
perfhelp () {
	local help_content
	help_content=$(cat <<'EOF'
SHELL PROFILING
  zshbench [N]       → benchmark shell startup (N times, default 10)
  zshprof            → detailed zsh startup profile
  zshslow            → find slow-loading config files
  findslow           → find files slowing down startup

COMMAND TIMING
  timecmd <cmd>      → time a command with statistics
  timecmp <c1> <c2>  → compare two commands
  benchops           → benchmark common operations

SYSTEM MONITORING
  perfcheck          → system performance overview
  perfmon [N]        → real-time monitor (htop/btop/top)
  iomon [N]          → disk I/O monitor (iostat)
  netmon             → network traffic monitor (iftop)
  cpucores           → CPU usage per core

PROCESS MONITORING
  memleak <pid> [N]  → track memory usage over time
  topcpu             → top processes by CPU (from system.zsh)
  topmem             → top processes by memory (from system.zsh)

CACHE MANAGEMENT
  clearcache         → clear shell and completion caches
EOF
) 
	_show_help "Performance Monitoring" "$help_content"
}
perfmon () {
	local interval="${1:-2}" 
	if command -v htop > /dev/null 2>&1
	then
		htop
	elif command -v btop > /dev/null 2>&1
	then
		btop
	elif command -v top > /dev/null 2>&1
	then
		top
	else
		echo "No performance monitor found. Install htop or btop:"
		echo "  sudo dnf install htop"
		echo "  # or"
		echo "  sudo dnf install btop"
	fi
}
pgcreate () {
	local dbname="${1}" 
	if [[ -z "$dbname" ]]
	then
		echo "Usage: pgcreate <database-name>"
		return 1
	fi
	createdb "$dbname"
	echo "Created PostgreSQL database: $dbname"
}
pgdrop () {
	local dbname="${1}" 
	if [[ -z "$dbname" ]]
	then
		echo "Usage: pgdrop <database-name>"
		return 1
	fi
	read "?Drop database '$dbname'? This cannot be undone. (y/N): " answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		dropdb "$dbname"
		echo "Dropped PostgreSQL database: $dbname"
	else
		echo "Cancelled"
	fi
}
pgdumppick () {
	local db
	db=$(psql -l -t | awk '{print $1}' | grep -v '^$' | grep -v 'template' \
    | fzf --height 40% --prompt "Dump PostgreSQL DB> ")  || return
	local filename="${db}_$(date +%Y%m%d_%H%M%S).sql" 
	echo "Dumping $db to $filename..."
	pg_dump "$db" > "$filename"
	echo "Done! Saved to $filename"
}
pgpick () {
	local db
	db=$(psql -l -t | awk '{print $1}' | grep -v '^$' | grep -v 'template' \
    | fzf --height 40% --prompt "PostgreSQL DB> ")  || return
	psql "$db"
}
pgtables () {
	local db="${1:-postgres}" 
	psql "$db" -c "
    SELECT
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
    FROM pg_tables
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
  "
}
pingmulti () {
	local hosts=("8.8.8.8" "1.1.1.1" "google.com" "github.com") 
	for host in $hosts
	do
		echo "Pinging $host..."
		ping -c 2 "$host" || echo "Failed to reach $host"
		echo ""
	done
}
pipshow () {
	local pkg
	pkg=$(pip list --format=columns | tail -n +3 | awk '{print $1}' \
    | fzf --height 40% --prompt "Package> " \
        --preview "pip show {}")  || return
	pip show "$pkg"
}
porm () {
	local dep
	dep=$(poetry show | awk '{print $1}' \
    | fzf --height 40% --prompt "Remove Package> " \
        --preview "poetry show {}")  || return
	poetry remove "$dep"
}
portpick () {
	local port_line
	port_line=$(ss -tuln | tail -n +2 \
    | fzf --height 40% --prompt "Listening Port> " \
        --preview "echo {}")  || return
	local port=$(echo "$port_line" | awk '{print $5}' | rev | cut -d: -f1 | rev) 
	echo "Port: $port"
	sudo lsof -i ":$port"
}
portscan () {
	local host="${1}" 
	local start_port="${2:-1}" 
	local end_port="${3:-1024}" 
	if [[ -z "$host" ]]
	then
		echo "Usage: portscan <host> [start-port] [end-port]"
		return 1
	fi
	echo "Scanning $host from port $start_port to $end_port..."
	for port in $(seq "$start_port" "$end_port")
	do
		ninja -C build clean -z -v -w 1 "$host" "$port" 2>&1 | grep succeeded
	done
}
portslist () {
	echo "=== Listening Ports ==="
	sudo lsof -iTCP -sTCP:LISTEN -n -P | awk 'NR==1 || /LISTEN/'
	echo ""
	echo "=== Established Connections ==="
	sudo lsof -iTCP -sTCP:ESTABLISHED -n -P | awk 'NR==1 || /ESTABLISHED/' | head -20
}
pos () {
	local env_path
	env_path="$(poetry env info --path)"  || return 1
	source "$env_path/bin/activate"
}
powerlevel10k_plugin_unload () {
	prompt_powerlevel9k_teardown
}
print_icon () {
	eval "$__p9k_intro"
	_p9k_init_icons
	local var=POWERLEVEL9K_$1 
	if (( $+parameters[$var] ))
	then
		echo -n - ${(P)var}
	else
		echo -n - $icons[$1]
	fi
}
proj () {
	local files=(README.md package.json pyproject.toml requirements.txt Cargo.toml go.mod Makefile Dockerfile docker-compose.yml .env.example) 
	local opened=0 
	for f in $files
	do
		if [[ -f "$f" ]]
		then
			$EDITOR "$f" &
			opened=$((opened + 1)) 
		fi
	done
	if [[ $opened -eq 0 ]]
	then
		echo "No common project files found"
		echo "Opening current directory in editor..."
		$EDITOR .
	else
		echo "Opened $opened project file(s) in $EDITOR"
	fi
}
projroot () {
	local dir="$PWD" 
	while [[ "$dir" != "/" ]]
	do
		if [[ -d "$dir/.git" ]] || [[ -f "$dir/package.json" ]] || [[ -f "$dir/Cargo.toml" ]] || [[ -f "$dir/go.mod" ]] || [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/Makefile" ]]
		then
			echo "$dir"
			return 0
		fi
		dir=$(dirname "$dir") 
	done
	echo "Not in a project directory"
	return 1
}
prompt__p9k_internal_nothing () {
	_p9k__prompt+='${_p9k__sss::=}' 
}
prompt_anaconda () {
	local msg
	if _p9k_python_version
	then
		P9K_ANACONDA_PYTHON_VERSION=$_p9k__ret 
		if (( _POWERLEVEL9K_ANACONDA_SHOW_PYTHON_VERSION ))
		then
			msg="${P9K_ANACONDA_PYTHON_VERSION//\%/%%} " 
		fi
	else
		unset P9K_ANACONDA_PYTHON_VERSION
	fi
	local p=${CONDA_PREFIX:-$CONDA_ENV_PATH} 
	msg+="$_POWERLEVEL9K_ANACONDA_LEFT_DELIMITER${${p:t}//\%/%%}$_POWERLEVEL9K_ANACONDA_RIGHT_DELIMITER" 
	_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PYTHON_ICON' 0 '' "$msg"
}
prompt_asdf () {
	_p9k_asdf_check_meta || _p9k_asdf_init_meta || return
	local -A versions
	local -a stat
	local -i has_global
	local dirs=($_p9k__parent_dirs) 
	local mtimes=($_p9k__parent_mtimes) 
	if [[ $dirs[-1] != ~ ]]
	then
		zstat -A stat +mtime ~ 2> /dev/null || return
		dirs+=(~) 
		mtimes+=($stat[1]) 
	fi
	local elem
	for elem in ${(@)${:-{1..$#dirs}}/(#m)*/${${:-$MATCH:$_p9k__asdf_dir2files[$dirs[MATCH]]}#$MATCH:$mtimes[MATCH]:}}
	do
		if [[ $elem == *:* ]]
		then
			local dir=$dirs[${elem%%:*}] 
			zstat -A stat +mtime $dir 2> /dev/null || return
			local files=($dir/.tool-versions(N) $dir/${(k)^_p9k_asdf_file_info}(N)) 
			_p9k__asdf_dir2files[$dir]=$stat[1]:${(pj:\0:)files} 
		else
			local files=(${(0)elem}) 
		fi
		if [[ ${files[1]:h} == ~ ]]
		then
			has_global=1 
			local -A local_versions=(${(kv)versions}) 
			versions=() 
		fi
		local file
		for file in $files
		do
			[[ $file == */.tool-versions ]]
			_p9k_asdf_parse_version_file $file $? || return
		done
	done
	if (( ! has_global ))
	then
		has_global=1 
		local -A local_versions=(${(kv)versions}) 
		versions=() 
	fi
	if [[ -r $ASDF_DEFAULT_TOOL_VERSIONS_FILENAME ]]
	then
		_p9k_asdf_parse_version_file $ASDF_DEFAULT_TOOL_VERSIONS_FILENAME 0 || return
	fi
	local plugin
	for plugin in ${(k)_p9k_asdf_plugins}
	do
		local upper=${${(U)plugin//-/_}//İ/I} 
		if (( $+parameters[_POWERLEVEL9K_ASDF_${upper}_SOURCES] ))
		then
			local sources=(${(P)${:-_POWERLEVEL9K_ASDF_${upper}_SOURCES}}) 
		else
			local sources=($_POWERLEVEL9K_ASDF_SOURCES) 
		fi
		local version="${(P)${:-ASDF_${upper}_VERSION}}" 
		if [[ -n $version ]]
		then
			(( $sources[(I)shell] )) || continue
		else
			version=$local_versions[$plugin] 
			if [[ -n $version ]]
			then
				(( $sources[(I)local] )) || continue
			else
				version=$versions[$plugin] 
				[[ -n $version ]] || continue
				(( $sources[(I)global] )) || continue
			fi
		fi
		if [[ $version == $versions[$plugin] ]]
		then
			if (( $+parameters[_POWERLEVEL9K_ASDF_${upper}_PROMPT_ALWAYS_SHOW] ))
			then
				(( _POWERLEVEL9K_ASDF_${upper}_PROMPT_ALWAYS_SHOW )) || continue
			else
				(( _POWERLEVEL9K_ASDF_PROMPT_ALWAYS_SHOW )) || continue
			fi
		fi
		if [[ $version == system ]]
		then
			if (( $+parameters[_POWERLEVEL9K_ASDF_${upper}_SHOW_SYSTEM] ))
			then
				(( _POWERLEVEL9K_ASDF_${upper}_SHOW_SYSTEM )) || continue
			else
				(( _POWERLEVEL9K_ASDF_SHOW_SYSTEM )) || continue
			fi
		fi
		_p9k_get_icon $0_$upper ${upper}_ICON $plugin
		_p9k_prompt_segment $0_$upper green $_p9k_color1 $'\1'$_p9k__ret 0 '' ${version//\%/%%}
	done
}
prompt_aws () {
	typeset -g P9K_AWS_PROFILE="${AWS_SSO_PROFILE:-${AWS_VAULT:-${AWSUME_PROFILE:-${AWS_PROFILE:-$AWS_DEFAULT_PROFILE}}}}" 
	local pat class state
	for pat class in "${_POWERLEVEL9K_AWS_CLASSES[@]}"
	do
		if [[ $P9K_AWS_PROFILE == ${~pat} ]]
		then
			[[ -n $class ]] && state=_${${(U)class}//İ/I} 
			break
		fi
	done
	if [[ -n ${AWS_REGION:-$AWS_DEFAULT_REGION} ]]
	then
		typeset -g P9K_AWS_REGION=${AWS_REGION:-$AWS_DEFAULT_REGION} 
	else
		local cfg=${AWS_CONFIG_FILE:-~/.aws/config} 
		if ! _p9k_cache_stat_get $0 $cfg
		then
			local -a reply
			_p9k_parse_aws_config $cfg
			_p9k_cache_stat_set $reply
		fi
		local prefix=$#P9K_AWS_PROFILE:$P9K_AWS_PROFILE: 
		local kv=$_p9k__cache_val[(r)${(b)prefix}*] 
		typeset -g P9K_AWS_REGION=${kv#$prefix} 
	fi
	_p9k_prompt_segment "$0$state" red white 'AWS_ICON' 0 '' "${P9K_AWS_PROFILE//\%/%%}"
}
prompt_aws_eb_env () {
	_p9k_upglob .elasticbeanstalk -/ && return
	local dir=$_p9k__parent_dirs[$?] 
	if ! _p9k_cache_stat_get $0 $dir/.elasticbeanstalk/config.yml
	then
		local env
		env="$(command eb list 2>/dev/null)"  || env= 
		env="${${(@M)${(@f)env}:#\* *}#\* }" 
		_p9k_cache_stat_set "$env"
	fi
	[[ -n $_p9k__cache_val[1] ]] || return
	_p9k_prompt_segment "$0" black green 'AWS_EB_ICON' 0 '' "${_p9k__cache_val[1]//\%/%%}"
}
prompt_azure () {
	local name cfg=${AZURE_CONFIG_DIR:-$HOME/.azure}/azureProfile.json 
	if _p9k_cache_stat_get $0 $cfg
	then
		name=$_p9k__cache_val[1] 
	else
		if (( $+commands[jq] )) && name="$(jq -r '[.subscriptions[]|select(.isDefault==true)|.name][]|strings' $cfg 2>/dev/null)" 
		then
			name=${name%%$'\n'*} 
		elif ! name="$(az account show --query name --output tsv 2>/dev/null)" 
		then
			name= 
		fi
		_p9k_cache_stat_set "$name"
	fi
	[[ -n $name ]] || return
	local pat class state
	for pat class in "${_POWERLEVEL9K_AZURE_CLASSES[@]}"
	do
		if [[ $name == ${~pat} ]]
		then
			[[ -n $class ]] && state=_${${(U)class}//İ/I} 
			break
		fi
	done
	_p9k_prompt_segment "$0$state" "blue" "white" "AZURE_ICON" 0 '' "${name//\%/%%}"
}
prompt_background_jobs () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	local msg
	if (( _POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE ))
	then
		if (( _POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE_ALWAYS ))
		then
			msg='${(%):-%j}' 
		else
			msg='${${(%):-%j}:#1}' 
		fi
	fi
	_p9k_prompt_segment $0 "$_p9k_color1" cyan BACKGROUND_JOBS_ICON 1 '${${(%):-%j}:#0}' "$msg"
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_battery () {
	[[ $_p9k_os == (Linux|Android) ]] && _p9k_prompt_battery_set_args
	(( $#_p9k__battery_args )) && _p9k_prompt_segment "${_p9k__battery_args[@]}"
}
prompt_chezmoi_shell () {
	_p9k_prompt_segment $0 blue $_p9k_color1 CHEZMOI_ICON 0 '' ''
}
prompt_chruby () {
	local v=${(M)RUBY_ENGINE:#$~_POWERLEVEL9K_CHRUBY_SHOW_ENGINE_PATTERN} 
	[[ $_POWERLEVEL9K_CHRUBY_SHOW_VERSION == 1 && -n $RUBY_VERSION ]] && v+=${v:+ }$RUBY_VERSION 
	_p9k_prompt_segment "$0" "red" "$_p9k_color1" 'RUBY_ICON' 0 '' "${v//\%/%%}"
}
prompt_command_execution_time () {
	(( $+P9K_COMMAND_DURATION_SECONDS )) || return
	(( P9K_COMMAND_DURATION_SECONDS >= _POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD )) || return
	if (( P9K_COMMAND_DURATION_SECONDS < 60 ))
	then
		if (( !_POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION ))
		then
			local -i sec=$((P9K_COMMAND_DURATION_SECONDS + 0.5)) 
		else
			local -F $_POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION sec=P9K_COMMAND_DURATION_SECONDS 
		fi
		local text=${sec}s 
	else
		local -i d=$((P9K_COMMAND_DURATION_SECONDS + 0.5)) 
		if [[ $_POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT == "H:M:S" ]]
		then
			local text=${(l.2..0.)$((d % 60))} 
			if (( d >= 60 ))
			then
				text=${(l.2..0.)$((d / 60 % 60))}:$text 
				if (( d >= 36000 ))
				then
					text=$((d / 3600)):$text 
				elif (( d >= 3600 ))
				then
					text=0$((d / 3600)):$text 
				fi
			fi
		else
			local text="$((d % 60))s" 
			if (( d >= 60 ))
			then
				text="$((d / 60 % 60))m $text" 
				if (( d >= 3600 ))
				then
					text="$((d / 3600 % 24))h $text" 
					if (( d >= 86400 ))
					then
						text="$((d / 86400))d $text" 
					fi
				fi
			fi
		fi
	fi
	_p9k_prompt_segment "$0" "red" "yellow1" 'EXECUTION_TIME_ICON' 0 '' $text
}
prompt_context () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	local content
	if [[ $_POWERLEVEL9K_ALWAYS_SHOW_CONTEXT == 0 && -n $DEFAULT_USER && $P9K_SSH == 0 ]]
	then
		local user="${(%):-%n}" 
		if [[ $user == $DEFAULT_USER ]]
		then
			content="${user//\%/%%}" 
		fi
	fi
	local state
	if (( P9K_SSH ))
	then
		if [[ -n "$SUDO_COMMAND" ]]
		then
			state="REMOTE_SUDO" 
		else
			state="REMOTE" 
		fi
	elif [[ -n "$SUDO_COMMAND" ]]
	then
		state="SUDO" 
	else
		state="DEFAULT" 
	fi
	local cond
	for state cond in $state '${${(%):-%#}:#\#}' ROOT '${${(%):-%#}:#\%}'
	do
		local text=$content 
		if [[ -z $text ]]
		then
			local var=_POWERLEVEL9K_CONTEXT_${state}_TEMPLATE 
			if (( $+parameters[$var] ))
			then
				text=${(P)var} 
				text=${(g::)text} 
			else
				text=$_POWERLEVEL9K_CONTEXT_TEMPLATE 
			fi
		fi
		_p9k_prompt_segment "$0_$state" "$_p9k_color1" yellow '' 0 "$cond" "$text"
	done
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_cpu_arch () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	local state text
	if _p9k_cache_ephemeral_get $0
	then
		state=$_p9k__cache_val[1] 
		text=$_p9k__cache_val[2] 
	else
		if [[ -r /proc/sys/kernel/arch ]]
		then
			text=$(</proc/sys/kernel/arch) 
		else
			local cmd
			for cmd in machine arch
			do
				(( $+commands[$cmd] )) || continue
				if text=$(command -- $cmd)  2> /dev/null && [[ $text == [a-zA-Z][a-zA-Z0-9_]# ]]
				then
					break
				else
					text= 
				fi
			done
		fi
		state=_${${(U)text}//İ/I} 
		_p9k_cache_ephemeral_set "$state" "$text"
	fi
	if [[ -n $text ]]
	then
		_p9k_prompt_segment "$0$state" "yellow" "$_p9k_color1" 'ARCH_ICON' 0 '' "$text"
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_date () {
	if [[ $_p9k__refresh_reason == precmd ]]
	then
		if [[ $+__p9k_instant_prompt_active == 1 && $__p9k_instant_prompt_date_format == $_POWERLEVEL9K_DATE_FORMAT ]]
		then
			_p9k__date=${__p9k_instant_prompt_date//\%/%%} 
		else
			_p9k__date=${${(%)_POWERLEVEL9K_DATE_FORMAT}//\%/%%} 
		fi
	fi
	_p9k_prompt_segment "$0" "$_p9k_color2" "$_p9k_color1" "DATE_ICON" 0 '' "$_p9k__date"
}
prompt_detect_virt () {
	local virt="$(systemd-detect-virt 2>/dev/null)" 
	if [[ "$virt" == "none" ]]
	then
		local -a inode
		if zstat -A inode +inode / 2> /dev/null && [[ $inode[1] != 2 ]]
		then
			virt="chroot" 
		fi
	fi
	if [[ -n "${virt}" ]]
	then
		_p9k_prompt_segment "$0" "$_p9k_color1" "yellow" '' 0 '' "${virt//\%/%%}"
	fi
}
prompt_dir () {
	if (( _POWERLEVEL9K_DIR_PATH_ABSOLUTE ))
	then
		local p=${(V)_p9k__cwd} 
		local -a parts=("${(s:/:)p}") 
	elif [[ -o auto_name_dirs ]]
	then
		local p=${(V)${_p9k__cwd/#(#b)$HOME(|\/*)/'~'$match[1]}} 
		local -a parts=("${(s:/:)p}") 
	else
		local p=${(%):-%~} 
		if [[ $p == '~['* ]]
		then
			local func='' 
			local -a parts=() 
			for func in zsh_directory_name $zsh_directory_name_functions
			do
				local reply=() 
				if (( $+functions[$func] )) && $func d $_p9k__cwd && [[ $p == '~['${(V)reply[1]}']'* ]]
				then
					parts+='~['${(V)reply[1]}']' 
					break
				fi
			done
			if (( $#parts ))
			then
				parts+=(${(s:/:)${p#$parts[1]}}) 
			else
				p=${(V)_p9k__cwd} 
				parts=("${(s:/:)p}") 
			fi
		else
			local -a parts=("${(s:/:)p}") 
		fi
	fi
	local -i fake_first=0 expand=0 shortenlen=${_POWERLEVEL9K_SHORTEN_DIR_LENGTH:--1} 
	if (( $+_POWERLEVEL9K_SHORTEN_DELIMITER ))
	then
		local delim=$_POWERLEVEL9K_SHORTEN_DELIMITER 
	else
		if [[ $langinfo[CODESET] == (utf|UTF)(-|)8 ]]
		then
			local delim=$'\u2026' 
		else
			local delim='..' 
		fi
	fi
	case $_POWERLEVEL9K_SHORTEN_STRATEGY in
		(truncate_absolute | truncate_absolute_chars) if (( shortenlen > 0 && $#p > shortenlen ))
			then
				_p9k_shorten_delim_len $delim
				if (( $#p > shortenlen + $_p9k__ret ))
				then
					local -i n=shortenlen 
					local -i i=$#parts 
					while true
					do
						local dir=$parts[i] 
						local -i len=$(( $#dir + (i > 1) )) 
						if (( len <= n ))
						then
							(( n -= len ))
							(( --i ))
						else
							parts[i]=$'\1'$dir[-n,-1] 
							parts[1,i-1]=() 
							break
						fi
					done
				fi
			fi ;;
		(truncate_with_package_name | truncate_middle | truncate_from_right) () {
				[[ $_POWERLEVEL9K_SHORTEN_STRATEGY == truncate_with_package_name && $+commands[jq] == 1 && $#_POWERLEVEL9K_DIR_PACKAGE_FILES > 0 ]] || return
				local pats="(${(j:|:)_POWERLEVEL9K_DIR_PACKAGE_FILES})" 
				local -i i=$#parts 
				local dir=$_p9k__cwd 
				for ((; i > 0; --i )) do
					local markers=($dir/${~pats}(N)) 
					if (( $#markers ))
					then
						local pat= pkg_file= 
						for pat in $_POWERLEVEL9K_DIR_PACKAGE_FILES
						do
							for pkg_file in $markers
							do
								[[ $pkg_file == $dir/${~pat} ]] || continue
								if ! _p9k_cache_stat_get $0_pkg $pkg_file
								then
									local pkg_name='' 
									pkg_name="$(jq -j '.name | select(. != null)' <$pkg_file 2>/dev/null)"  || pkg_name='' 
									_p9k_cache_stat_set "$pkg_name"
								fi
								[[ -n $_p9k__cache_val[1] ]] || continue
								parts[1,i]=($_p9k__cache_val[1]) 
								fake_first=1 
								return 0
							done
						done
					fi
					dir=${dir:h} 
				done
			}
			if (( shortenlen > 0 ))
			then
				_p9k_shorten_delim_len $delim
				local -i d=_p9k__ret pref=shortenlen suf=0 i=2 
				[[ $_POWERLEVEL9K_SHORTEN_STRATEGY == truncate_middle ]] && suf=pref 
				for ((; i < $#parts; ++i )) do
					local dir=$parts[i] 
					if (( $#dir > pref + suf + d ))
					then
						dir[pref+1,-suf-1]=$'\1' 
						parts[i]=$dir 
					fi
				done
			fi ;;
		(truncate_to_last) shortenlen=${_POWERLEVEL9K_SHORTEN_DIR_LENGTH:-1} 
			(( shortenlen > 0 )) || shortenlen=1 
			local -i i='shortenlen+1' 
			if [[ $#parts -gt i || ( $p[1] != / && $#parts -gt shortenlen ) ]]
			then
				fake_first=1 
				parts[1,-i]=() 
			fi ;;
		(truncate_to_first_and_last) if (( shortenlen > 0 ))
			then
				local -i i=$(( shortenlen + 1 )) 
				[[ $p == /* ]] && (( ++i ))
				for ((; i <= $#parts - shortenlen; ++i )) do
					parts[i]=$'\1' 
				done
			fi ;;
		(truncate_to_unique) expand=1 
			delim=${_POWERLEVEL9K_SHORTEN_DELIMITER-'*'} 
			shortenlen=${_POWERLEVEL9K_SHORTEN_DIR_LENGTH:-1} 
			(( shortenlen >= 0 )) || shortenlen=1 
			local rp=${(g:oce:)p} 
			local rparts=("${(@s:/:)rp}") 
			local -i i=2 e=$(($#parts - shortenlen)) 
			if [[ -n $_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER ]]
			then
				(( e += shortenlen ))
				local orig=("$parts[2]" "${(@)parts[$((shortenlen > $#parts ? -$#parts : -shortenlen)),-1]}") 
			elif [[ $p[1] == / ]]
			then
				(( ++i ))
			fi
			if (( i <= e ))
			then
				local mtimes=(${(Oa)_p9k__parent_mtimes:$(($#parts-e)):$((e-i+1))}) 
				local key="${(pj.:.)mtimes}" 
			else
				local key= 
			fi
			if ! _p9k_cache_ephemeral_get $0 $e $i $_p9k__cwd $p || [[ $key != $_p9k__cache_val[1] ]]
			then
				local rtail=${(j./.)rparts[i,-1]} 
				local parent=$_p9k__cwd[1,-2-$#rtail] 
				_p9k_prompt_length $delim
				local -i real_delim_len=_p9k__ret 
				[[ -n $parts[i-1] ]] && parts[i-1]="\${(Q)\${:-${(qqq)${(q)parts[i-1]}}}}"$'\2' 
				local -i d=${_POWERLEVEL9K_SHORTEN_DELIMITER_LENGTH:--1} 
				(( d >= 0 )) || d=real_delim_len 
				local -i m=1 
				for ((; i <= e; ++i, ++m )) do
					local sub=$parts[i] 
					local rsub=$rparts[i] 
					local dir=$parent/$rsub mtime=$mtimes[m] 
					local pair=$_p9k__dir_stat_cache[$dir] 
					if [[ $pair == ${mtime:-x}:* ]]
					then
						parts[i]=${pair#*:} 
					else
						[[ $sub != *["~!#\`\$^&*()\\\"'<>?{}[]"]* ]]
						local -i q=$? 
						if [[ -n $_POWERLEVEL9K_SHORTEN_FOLDER_MARKER && -n $dir/${~_POWERLEVEL9K_SHORTEN_FOLDER_MARKER}(#qN) ]]
						then
							(( q )) && parts[i]="\${(Q)\${:-${(qqq)${(q)sub}}}}" 
							parts[i]+=$'\2' 
						else
							local -i j=$rsub[(i)[^.]] 
							for ((; j + d < $#rsub; ++j )) do
								local -a matching=($parent/$rsub[1,j]*/(N)) 
								(( $#matching == 1 )) && break
							done
							local -i saved=$((${(m)#${(V)${rsub:$j}}} - d)) 
							if (( saved > 0 ))
							then
								if (( q ))
								then
									parts[i]='${${${_p9k__d:#-*}:+${(Q)${:-'${(qqq)${(q)sub}}'}}}:-${(Q)${:-' 
									parts[i]+=$'\3'${(qqq)${(q)${(V)${rsub[1,j]}}}}$'}}\1\3''${$((_p9k__d+='$saved'))+}}' 
								else
									parts[i]='${${${_p9k__d:#-*}:+'$sub$'}:-\3'${(V)${rsub[1,j]}}$'\1\3''${$((_p9k__d+='$saved'))+}}' 
								fi
							else
								(( q )) && parts[i]="\${(Q)\${:-${(qqq)${(q)sub}}}}" 
							fi
						fi
						[[ -n $mtime ]] && _p9k__dir_stat_cache[$dir]="$mtime:$parts[i]" 
					fi
					parent+=/$rsub 
				done
				if [[ -n $_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER ]]
				then
					local _2=$'\2' 
					if [[ $_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER == last* ]]
					then
						(( e = ${parts[(I)*$_2]} + ${_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER#*:} ))
					else
						(( e = ${parts[(ib:2:)*$_2]} + ${_POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER#*:} ))
					fi
					if (( e > 1 && e <= $#parts ))
					then
						parts[1,e-1]=() 
						fake_first=1 
					elif [[ $p == /?* ]]
					then
						parts[2]="\${(Q)\${:-${(qqq)${(q)orig[1]}}}}"$'\2' 
					fi
					for ((i = $#parts < shortenlen ? $#parts : shortenlen; i > 0; --i)) do
						[[ $#parts[-i] == *$'\2' ]] && continue
						if [[ $orig[-i] == *["~!#\`\$^&*()\\\"'<>?{}[]"]* ]]
						then
							parts[-i]='${(Q)${:-'${(qqq)${(q)orig[-i]}}'}}'$'\2' 
						else
							parts[-i]=${orig[-i]}$'\2' 
						fi
					done
				else
					for ((; i <= $#parts; ++i)) do
						[[ $parts[i] == *["~!#\`\$^&*()\\\"'<>?{}[]"]* ]] && parts[i]='${(Q)${:-'${(qqq)${(q)parts[i]}}'}}' 
						parts[i]+=$'\2' 
					done
				fi
				_p9k_cache_ephemeral_set "$key" "${parts[@]}"
			fi
			parts=("${(@)_p9k__cache_val[2,-1]}")  ;;
		(truncate_with_folder_marker) if [[ -n $_POWERLEVEL9K_SHORTEN_FOLDER_MARKER ]]
			then
				local dir=$_p9k__cwd 
				local -a m=() 
				local -i i=$(($#parts - 1)) 
				for ((; i > 1; --i )) do
					dir=${dir:h} 
					[[ -n $dir/${~_POWERLEVEL9K_SHORTEN_FOLDER_MARKER}(#qN) ]] && m+=$i 
				done
				m+=1 
				for ((i=1; i < $#m; ++i )) do
					(( m[i] - m[i+1] > 2 )) && parts[m[i+1]+1,m[i]-1]=($'\1') 
				done
			fi ;;
		(*) if (( shortenlen > 0 ))
			then
				local -i len=$#parts 
				[[ -z $parts[1] ]] && (( --len ))
				if (( len > shortenlen ))
				then
					parts[1,-shortenlen-1]=($'\1') 
				fi
			fi ;;
	esac
	(( !_POWERLEVEL9K_DIR_SHOW_WRITABLE )) || [[ -w $_p9k__cwd ]]
	local -i w=$? 
	(( w && _POWERLEVEL9K_DIR_SHOW_WRITABLE > 2 )) && [[ ! -e $_p9k__cwd ]] && w=2 
	if ! _p9k_cache_ephemeral_get $0 $_p9k__cwd $p $w $fake_first "${parts[@]}"
	then
		local state=$0 
		local icon='' 
		local a='' b='' c='' 
		for a b c in "${_POWERLEVEL9K_DIR_CLASSES[@]}"
		do
			if [[ $_p9k__cwd == ${~a} ]]
			then
				[[ -n $b ]] && state+=_${${(U)b}//İ/I} 
				icon=$'\1'$c 
				break
			fi
		done
		if (( w ))
		then
			if (( _POWERLEVEL9K_DIR_SHOW_WRITABLE == 1 ))
			then
				state=${0}_NOT_WRITABLE 
			elif (( w == 2 ))
			then
				state+=_NON_EXISTENT 
			else
				state+=_NOT_WRITABLE 
			fi
			icon=LOCK_ICON 
		fi
		local state_u=${${(U)state}//İ/I} 
		local style=%b 
		_p9k_color $state BACKGROUND blue
		_p9k_background $_p9k__ret
		style+=$_p9k__ret 
		_p9k_color $state FOREGROUND "$_p9k_color1"
		_p9k_foreground $_p9k__ret
		style+=$_p9k__ret 
		if (( expand ))
		then
			_p9k_escape_style $style
			style=$_p9k__ret 
		fi
		parts=("${(@)parts//\%/%%}") 
		if [[ $_POWERLEVEL9K_HOME_FOLDER_ABBREVIATION != '~' && $fake_first == 0 && $p == ('~'|'~/'*) ]]
		then
			(( expand )) && _p9k_escape $_POWERLEVEL9K_HOME_FOLDER_ABBREVIATION || _p9k__ret=$_POWERLEVEL9K_HOME_FOLDER_ABBREVIATION 
			parts[1]=$_p9k__ret 
			[[ $_p9k__ret == *%* ]] && parts[1]+=$style 
		elif [[ $_POWERLEVEL9K_DIR_OMIT_FIRST_CHARACTER == 1 && $fake_first == 0 && $#parts > 1 && -z $parts[1] && -n $parts[2] ]]
		then
			parts[1]=() 
		fi
		local last_style= 
		_p9k_param $state PATH_HIGHLIGHT_BOLD ''
		[[ $_p9k__ret == true ]] && last_style+=%B 
		if (( $+parameters[_POWERLEVEL9K_DIR_PATH_HIGHLIGHT_FOREGROUND] ||
          $+parameters[_POWERLEVEL9K_${state_u}_PATH_HIGHLIGHT_FOREGROUND] ))
		then
			_p9k_color $state PATH_HIGHLIGHT_FOREGROUND ''
			_p9k_foreground $_p9k__ret
			last_style+=$_p9k__ret 
		fi
		if [[ -n $last_style ]]
		then
			(( expand )) && _p9k_escape_style $last_style || _p9k__ret=$last_style 
			parts[-1]=$_p9k__ret${parts[-1]//$'\1'/$'\1'$_p9k__ret}$style 
		fi
		local anchor_style= 
		_p9k_param $state ANCHOR_BOLD ''
		[[ $_p9k__ret == true ]] && anchor_style+=%B 
		if (( $+parameters[_POWERLEVEL9K_DIR_ANCHOR_FOREGROUND] ||
          $+parameters[_POWERLEVEL9K_${state_u}_ANCHOR_FOREGROUND] ))
		then
			_p9k_color $state ANCHOR_FOREGROUND ''
			_p9k_foreground $_p9k__ret
			anchor_style+=$_p9k__ret 
		fi
		if [[ -n $anchor_style ]]
		then
			(( expand )) && _p9k_escape_style $anchor_style || _p9k__ret=$anchor_style 
			if [[ -z $last_style ]]
			then
				parts=("${(@)parts/%(#b)(*)$'\2'/$_p9k__ret$match[1]$style}") 
			else
				(( $#parts > 1 )) && parts[1,-2]=("${(@)parts[1,-2]/%(#b)(*)$'\2'/$_p9k__ret$match[1]$style}") 
				parts[-1]=${parts[-1]/$'\2'} 
			fi
		else
			parts=("${(@)parts/$'\2'}") 
		fi
		if (( $+parameters[_POWERLEVEL9K_DIR_SHORTENED_FOREGROUND] ||
          $+parameters[_POWERLEVEL9K_${state_u}_SHORTENED_FOREGROUND] ))
		then
			_p9k_color $state SHORTENED_FOREGROUND ''
			_p9k_foreground $_p9k__ret
			(( expand )) && _p9k_escape_style $_p9k__ret
			local shortened_fg=$_p9k__ret 
			(( expand )) && _p9k_escape $delim || _p9k__ret=$delim 
			[[ $_p9k__ret == *%* ]] && _p9k__ret+=$style$shortened_fg 
			parts=("${(@)parts/(#b)$'\3'(*)$'\1'(*)$'\3'/$shortened_fg$match[1]$_p9k__ret$match[2]$style}") 
			parts=("${(@)parts/(#b)(*)$'\1'(*)/$shortened_fg$match[1]$_p9k__ret$match[2]$style}") 
		else
			(( expand )) && _p9k_escape $delim || _p9k__ret=$delim 
			[[ $_p9k__ret == *%* ]] && _p9k__ret+=$style 
			parts=("${(@)parts/$'\1'/$_p9k__ret}") 
			parts=("${(@)parts//$'\3'}") 
		fi
		if [[ $_p9k__cwd == / && $_POWERLEVEL9K_DIR_OMIT_FIRST_CHARACTER == 1 ]]
		then
			local sep='/' 
		else
			local sep='' 
			if (( $+parameters[_POWERLEVEL9K_DIR_PATH_SEPARATOR_FOREGROUND] ||
            $+parameters[_POWERLEVEL9K_${state_u}_PATH_SEPARATOR_FOREGROUND] ))
			then
				_p9k_color $state PATH_SEPARATOR_FOREGROUND ''
				_p9k_foreground $_p9k__ret
				(( expand )) && _p9k_escape_style $_p9k__ret
				sep=$_p9k__ret 
			fi
			_p9k_param $state PATH_SEPARATOR /
			_p9k__ret=${(g::)_p9k__ret} 
			(( expand )) && _p9k_escape $_p9k__ret
			sep+=$_p9k__ret 
			[[ $sep == *%* ]] && sep+=$style 
		fi
		local content="${(pj.$sep.)parts}" 
		if (( _POWERLEVEL9K_DIR_HYPERLINK && _p9k_term_has_href )) && [[ $_p9k__cwd == /* ]]
		then
			_p9k_url_escape $_p9k__cwd
			local header=$'%{\e]8;;file://'$_p9k__ret$'\a%}' 
			local footer=$'%{\e]8;;\a%}' 
			if (( expand ))
			then
				_p9k_escape $header
				header=$_p9k__ret 
				_p9k_escape $footer
				footer=$_p9k__ret 
			fi
			content=$header$content$footer 
		fi
		(( expand )) && _p9k_prompt_length "${(e):-"\${\${_p9k__d::=0}+}$content"}" || _p9k__ret= 
		_p9k_cache_ephemeral_set "$state" "$icon" "$expand" "$content" $_p9k__ret
	fi
	if (( _p9k__cache_val[3] ))
	then
		if (( $+_p9k__dir ))
		then
			_p9k__cache_val[4]='${${_p9k__d::=-1024}+}'$_p9k__cache_val[4] 
		else
			_p9k__dir=$_p9k__cache_val[4] 
			_p9k__dir_len=$_p9k__cache_val[5] 
			_p9k__cache_val[4]='%{d%}'$_p9k__cache_val[4]'%{d%}' 
		fi
	fi
	_p9k_prompt_segment "$_p9k__cache_val[1]" "blue" "$_p9k_color1" "$_p9k__cache_val[2]" "$_p9k__cache_val[3]" "" "$_p9k__cache_val[4]"
}
prompt_dir_writable () {
	if [[ ! -w "$_p9k__cwd_a" ]]
	then
		_p9k_prompt_segment "$0_FORBIDDEN" "red" "yellow1" 'LOCK_ICON' 0 '' ''
	fi
}
prompt_direnv () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 $_p9k_color1 yellow DIRENV_ICON 0 '${DIRENV_DIR-}' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_disk_usage () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0_CRITICAL red white DISK_ICON 1 '$_p9k__disk_usage_critical' '$_p9k__disk_usage_pct%%'
	_p9k_prompt_segment $0_WARNING yellow $_p9k_color1 DISK_ICON 1 '$_p9k__disk_usage_warning' '$_p9k__disk_usage_pct%%'
	if (( ! _POWERLEVEL9K_DISK_USAGE_ONLY_WARNING ))
	then
		_p9k_prompt_segment $0_NORMAL $_p9k_color1 yellow DISK_ICON 1 '$_p9k__disk_usage_normal' '$_p9k__disk_usage_pct%%'
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_docker_machine () {
	_p9k_prompt_segment "$0" "magenta" "$_p9k_color1" 'SERVER_ICON' 0 '' "${DOCKER_MACHINE_NAME//\%/%%}"
}
prompt_dotnet_version () {
	if (( _POWERLEVEL9K_DOTNET_VERSION_PROJECT_ONLY ))
	then
		_p9k_upglob 'project.json|global.json|packet.dependencies|*.csproj|*.fsproj|*.xproj|*.sln' -. && return
	fi
	local cfg
	_p9k_upglob global.json -. || cfg=$_p9k__parent_dirs[$?]/global.json 
	_p9k_cached_cmd 0 "$cfg" dotnet --version || return
	_p9k_prompt_segment "$0" "magenta" "white" 'DOTNET_ICON' 0 '' "$_p9k__ret"
}
prompt_dropbox () {
	local dropbox_status="$(dropbox-cli filestatus . | cut -d\  -f2-)" 
	if [[ "$dropbox_status" != 'unwatched' && "$dropbox_status" != "isn't running!" ]]
	then
		if [[ "$dropbox_status" =~ 'up to date' ]]
		then
			dropbox_status="" 
		fi
		_p9k_prompt_segment "$0" "white" "blue" "DROPBOX_ICON" 0 '' "${dropbox_status//\%/%%}"
	fi
}
prompt_example () {
	p10k segment -f 208 -i '⭐' -t 'hello, %n'
}
prompt_fvm () {
	_p9k_fvm_new || _p9k_fvm_old
}
prompt_gcloud () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0_PARTIAL blue white GCLOUD_ICON 1 '${${(M)${#P9K_GCLOUD_PROJECT_NAME}:#0}:+$P9K_GCLOUD_ACCOUNT$P9K_GCLOUD_PROJECT_ID}' '${P9K_GCLOUD_ACCOUNT//\%/%%}:${P9K_GCLOUD_PROJECT_ID//\%/%%}'
	_p9k_prompt_segment $0_COMPLETE blue white GCLOUD_ICON 1 '$P9K_GCLOUD_PROJECT_NAME' '${P9K_GCLOUD_ACCOUNT//\%/%%}:${P9K_GCLOUD_PROJECT_ID//\%/%%}'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_go_version () {
	_p9k_cached_cmd 0 '' go version || return
	[[ $_p9k__ret == (#b)*go([[:digit:].]##)* ]] || return
	local v=$match[1] 
	if (( _POWERLEVEL9K_GO_VERSION_PROJECT_ONLY ))
	then
		local p=$GOPATH 
		if [[ -z $p ]]
		then
			if [[ -d $HOME/go ]]
			then
				p=$HOME/go 
			else
				p="$(go env GOPATH 2>/dev/null)"  && [[ -n $p ]] || return
			fi
		fi
		if [[ $_p9k__cwd/ != $p/* && $_p9k__cwd_a/ != $p/* ]]
		then
			_p9k_upglob go.mod -. && return
		fi
	fi
	_p9k_prompt_segment "$0" "green" "grey93" "GO_ICON" 0 '' "${v//\%/%%}"
}
prompt_goenv () {
	local v=${(j.:.)${(@)${(s.:.)GOENV_VERSION}#go-}} 
	if [[ -n $v ]]
	then
		(( ${_POWERLEVEL9K_GOENV_SOURCES[(I)shell]} )) || return
	else
		(( ${_POWERLEVEL9K_GOENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $GOENV_DIR != (|.) ]]
		then
			[[ $GOENV_DIR == /* ]] && local dir=$GOENV_DIR  || local dir="$_p9k__cwd_a/$GOENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_pyenv_like_version_file $dir/.go-version go-
					then
						(( ${_POWERLEVEL9K_GOENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .go-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_pyenv_like_version_file $_p9k__parent_dirs[idx]/.go-version go-
			then
				(( ${_POWERLEVEL9K_GOENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_GOENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_GOENV_SOURCES[(I)global]} )) || return
			_p9k_goenv_global_version
		fi
		v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_GOENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_goenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_GOENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'GO_ICON' 0 '' "${v//\%/%%}"
}
prompt_google_app_cred () {
	unset P9K_GOOGLE_APP_CRED_{TYPE,PROJECT_ID,CLIENT_EMAIL}
	if ! _p9k_cache_stat_get $0 $GOOGLE_APPLICATION_CREDENTIALS
	then
		local -a lines
		local q='[.type//"", .project_id//"", .client_email//"", 0][]' 
		if lines=("${(@f)$(jq -r $q <$GOOGLE_APPLICATION_CREDENTIALS 2>/dev/null)}")  && (( $#lines == 4 ))
		then
			local text="${(j.:.)lines[1,-2]}" 
			local pat class state
			for pat class in "${_POWERLEVEL9K_GOOGLE_APP_CRED_CLASSES[@]}"
			do
				if [[ $text == ${~pat} ]]
				then
					[[ -n $class ]] && state=_${${(U)class}//İ/I} 
					break
				fi
			done
			_p9k_cache_stat_set 1 "${(@)lines[1,-2]}" "$text" "$state"
		else
			_p9k_cache_stat_set 0
		fi
	fi
	(( _p9k__cache_val[1] )) || return
	P9K_GOOGLE_APP_CRED_TYPE=$_p9k__cache_val[2] 
	P9K_GOOGLE_APP_CRED_PROJECT_ID=$_p9k__cache_val[3] 
	P9K_GOOGLE_APP_CRED_CLIENT_EMAIL=$_p9k__cache_val[4] 
	_p9k_prompt_segment "$0$_p9k__cache_val[6]" "blue" "white" "GCLOUD_ICON" 0 '' "$_p9k__cache_val[5]"
}
prompt_haskell_stack () {
	if [[ -n $STACK_YAML ]]
	then
		(( ${_POWERLEVEL9K_HASKELL_STACK_SOURCES[(I)shell]} )) || return
		_p9k_haskell_stack_version $STACK_YAML
	else
		(( ${_POWERLEVEL9K_HASKELL_STACK_SOURCES[(I)local|global]} )) || return
		if _p9k_upglob stack.yaml -.
		then
			(( _POWERLEVEL9K_HASKELL_STACK_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_HASKELL_STACK_SOURCES[(I)global]} )) || return
			_p9k_haskell_stack_version ${STACK_ROOT:-~/.stack}/global-project/stack.yaml
		else
			local -i idx=$? 
			(( ${_POWERLEVEL9K_HASKELL_STACK_SOURCES[(I)local]} )) || return
			_p9k_haskell_stack_version $_p9k__parent_dirs[idx]/stack.yaml
		fi
	fi
	[[ -n $_p9k__ret ]] || return
	local v=$_p9k__ret 
	if (( !_POWERLEVEL9K_HASKELL_STACK_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_haskell_stack_version ${STACK_ROOT:-~/.stack}/global-project/stack.yaml
		[[ $v == $_p9k__ret ]] && return
	fi
	_p9k_prompt_segment "$0" "yellow" "$_p9k_color1" 'HASKELL_ICON' 0 '' "${v//\%/%%}"
}
prompt_history () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "$0" "grey50" "$_p9k_color1" '' 0 '' '%h'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_host () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	if (( P9K_SSH ))
	then
		_p9k_prompt_segment "$0_REMOTE" "${_p9k_color1}" yellow SSH_ICON 0 '' "$_POWERLEVEL9K_HOST_TEMPLATE"
	else
		_p9k_prompt_segment "$0_LOCAL" "${_p9k_color1}" yellow HOST_ICON 0 '' "$_POWERLEVEL9K_HOST_TEMPLATE"
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_ip () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "$0" "cyan" "$_p9k_color1" 'NETWORK_ICON' 1 '$P9K_IP_IP' '$P9K_IP_IP'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_java_version () {
	if (( _POWERLEVEL9K_JAVA_VERSION_PROJECT_ONLY ))
	then
		_p9k_upglob 'pom.xml|build.gradle.kts|build.sbt|deps.edn|project.clj|build.boot|*.(java|class|jar|gradle|clj|cljc)' -. && return
	fi
	local java=$commands[java] 
	if ! _p9k_cache_stat_get $0 $java ${JAVA_HOME:+$JAVA_HOME/release}
	then
		local v
		v="$(java -fullversion 2>&1)"  || v= 
		v=${${v#*\"}%\"*} 
		(( _POWERLEVEL9K_JAVA_VERSION_FULL )) || v=${v%%-*} 
		_p9k_cache_stat_set "${v//\%/%%}"
	fi
	[[ -n $_p9k__cache_val[1] ]] || return
	_p9k_prompt_segment "$0" "red" "white" "JAVA_ICON" 0 '' $_p9k__cache_val[1]
}
prompt_jenv () {
	if [[ -n $JENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_JENV_SOURCES[(I)shell]} )) || return
		local v=$JENV_VERSION 
	else
		(( ${_POWERLEVEL9K_JENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $JENV_DIR != (|.) ]]
		then
			[[ $JENV_DIR == /* ]] && local dir=$JENV_DIR  || local dir="$_p9k__cwd_a/$JENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.java-version
					then
						(( ${_POWERLEVEL9K_JENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .java-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.java-version
			then
				(( ${_POWERLEVEL9K_JENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_JENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_JENV_SOURCES[(I)global]} )) || return
			_p9k_jenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_JENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_jenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_JENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" white red 'JAVA_ICON' 0 '' "${v//\%/%%}"
}
prompt_kubecontext () {
	if ! _p9k_cache_stat_get $0 ${(s.:.)${KUBECONFIG:-$HOME/.kube/config}}
	then
		local name namespace cluster user cloud_name cloud_account cloud_zone cloud_cluster text state
		() {
			local cfg && cfg=(${(f)"$(kubectl config view -o=yaml 2>/dev/null)"})  || return
			local qstr='"*"' 
			local str='([^"'\''|>]*|'$qstr')' 
			local ctx=(${(@M)cfg:#current-context: $~str}) 
			(( $#ctx == 1 )) || return
			name=${ctx[1]#current-context: } 
			local -i pos=${cfg[(i)contexts:]} 
			{
				(( pos <= $#cfg )) || return
				shift $pos cfg
				pos=${cfg[(i)  name: ${(b)name}]} 
				(( pos <= $#cfg )) || return
				(( --pos ))
				for ((; pos > 0; --pos)) do
					local line=$cfg[pos] 
					if [[ $line == '- context:' ]]
					then
						return 0
					elif [[ $line == (#b)'    cluster: '($~str) ]]
					then
						cluster=$match[1] 
						[[ $cluster == $~qstr ]] && cluster=$cluster[2,-2] 
					elif [[ $line == (#b)'    namespace: '($~str) ]]
					then
						namespace=$match[1] 
						[[ $namespace == $~qstr ]] && namespace=$namespace[2,-2] 
					elif [[ $line == (#b)'    user: '($~str) ]]
					then
						user=$match[1] 
						[[ $user == $~qstr ]] && user=$user[2,-2] 
					fi
				done
			} always {
				[[ $name == $~qstr ]] && name=$name[2,-2] 
			}
		}
		if [[ -n $name ]]
		then
			: ${namespace:=default}
			if [[ $cluster == (#b)gke_(?*)_(asia|australia|europe|northamerica|southamerica|us)-([a-z]##<->)(-[a-z]|)_(?*) ]]
			then
				cloud_name=gke 
				cloud_account=$match[1] 
				cloud_zone=$match[2]-$match[3]$match[4] 
				cloud_cluster=$match[5] 
				if (( ${_POWERLEVEL9K_KUBECONTEXT_SHORTEN[(I)gke]} ))
				then
					text=$cloud_cluster 
				fi
			elif [[ $cluster == (#b)arn:aws[[:alnum:]-]#:eks:([[:alnum:]-]##):([[:digit:]]##):cluster/(?*) ]]
			then
				cloud_name=eks 
				cloud_zone=$match[1] 
				cloud_account=$match[2] 
				cloud_cluster=$match[3] 
				if (( ${_POWERLEVEL9K_KUBECONTEXT_SHORTEN[(I)eks]} ))
				then
					text=$cloud_cluster 
				fi
			fi
			if [[ -z $text ]]
			then
				text=$name 
				if [[ $_POWERLEVEL9K_KUBECONTEXT_SHOW_DEFAULT_NAMESPACE == 1 || $namespace != (default|$name) ]]
				then
					text+="/$namespace" 
				fi
			fi
			local pat class
			for pat class in "${_POWERLEVEL9K_KUBECONTEXT_CLASSES[@]}"
			do
				if [[ $text == ${~pat} ]]
				then
					[[ -n $class ]] && state=_${${(U)class}//İ/I} 
					break
				fi
			done
		fi
		_p9k_cache_stat_set "${(g::)name}" "${(g::)namespace}" "${(g::)cluster}" "${(g::)user}" "${(g::)cloud_name}" "${(g::)cloud_account}" "${(g::)cloud_zone}" "${(g::)cloud_cluster}" "${(g::)text}" "$state"
	fi
	typeset -g P9K_KUBECONTEXT_NAME=$_p9k__cache_val[1] 
	typeset -g P9K_KUBECONTEXT_NAMESPACE=$_p9k__cache_val[2] 
	typeset -g P9K_KUBECONTEXT_CLUSTER=$_p9k__cache_val[3] 
	typeset -g P9K_KUBECONTEXT_USER=$_p9k__cache_val[4] 
	typeset -g P9K_KUBECONTEXT_CLOUD_NAME=$_p9k__cache_val[5] 
	typeset -g P9K_KUBECONTEXT_CLOUD_ACCOUNT=$_p9k__cache_val[6] 
	typeset -g P9K_KUBECONTEXT_CLOUD_ZONE=$_p9k__cache_val[7] 
	typeset -g P9K_KUBECONTEXT_CLOUD_CLUSTER=$_p9k__cache_val[8] 
	[[ -n $_p9k__cache_val[9] ]] || return
	_p9k_prompt_segment $0$_p9k__cache_val[10] magenta white KUBERNETES_ICON 0 '' "${_p9k__cache_val[9]//\%/%%}"
}
prompt_laravel_version () {
	_p9k_upglob artisan && return
	local dir=$_p9k__parent_dirs[$?] 
	local app=$dir/vendor/laravel/framework/src/Illuminate/Foundation/Application.php 
	[[ -r $app ]] || return
	if ! _p9k_cache_stat_get $0 $dir/artisan $app
	then
		local v="$(php $dir/artisan --version 2> /dev/null)" 
		v="${${(M)v:#Laravel Framework *}#Laravel Framework }" 
		v=${${v#$'\e['<->m}%$'\e['<->m} 
		_p9k_cache_stat_set "$v"
	fi
	[[ -n $_p9k__cache_val[1] ]] || return
	_p9k_prompt_segment "$0" "maroon" "white" 'LARAVEL_ICON' 0 '' "${_p9k__cache_val[1]//\%/%%}"
}
prompt_lf () {
	_p9k_prompt_segment $0 6 $_p9k_color1 LF_ICON 0 '' $LF_LEVEL
}
prompt_load () {
	if [[ $_p9k_os == (OSX|BSD) ]]
	then
		local -i len=$#_p9k__prompt _p9k__has_upglob 
		_p9k_prompt_segment $0_CRITICAL red "$_p9k_color1" LOAD_ICON 1 '$_p9k__load_critical' '$_p9k__load_value'
		_p9k_prompt_segment $0_WARNING yellow "$_p9k_color1" LOAD_ICON 1 '$_p9k__load_warning' '$_p9k__load_value'
		_p9k_prompt_segment $0_NORMAL green "$_p9k_color1" LOAD_ICON 1 '$_p9k__load_normal' '$_p9k__load_value'
		(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
		return
	fi
	[[ -r /proc/loadavg ]] || return
	_p9k_read_file /proc/loadavg || return
	local load=${${(A)=_p9k__ret}[_POWERLEVEL9K_LOAD_WHICH]//,/.} 
	local -F pct='100. * load / _p9k_num_cpus' 
	if (( pct > _POWERLEVEL9K_LOAD_CRITICAL_PCT ))
	then
		_p9k_prompt_segment $0_CRITICAL red "$_p9k_color1" LOAD_ICON 0 '' $load
	elif (( pct > _POWERLEVEL9K_LOAD_WARNING_PCT ))
	then
		_p9k_prompt_segment $0_WARNING yellow "$_p9k_color1" LOAD_ICON 0 '' $load
	else
		_p9k_prompt_segment $0_NORMAL green "$_p9k_color1" LOAD_ICON 0 '' $load
	fi
}
prompt_luaenv () {
	if [[ -n $LUAENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_LUAENV_SOURCES[(I)shell]} )) || return
		local v=$LUAENV_VERSION 
	else
		(( ${_POWERLEVEL9K_LUAENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $LUAENV_DIR != (|.) ]]
		then
			[[ $LUAENV_DIR == /* ]] && local dir=$LUAENV_DIR  || local dir="$_p9k__cwd_a/$LUAENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.lua-version
					then
						(( ${_POWERLEVEL9K_LUAENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .lua-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.lua-version
			then
				(( ${_POWERLEVEL9K_LUAENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_LUAENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_LUAENV_SOURCES[(I)global]} )) || return
			_p9k_luaenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_LUAENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_luaenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_LUAENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" blue "$_p9k_color1" 'LUA_ICON' 0 '' "${v//\%/%%}"
}
prompt_midnight_commander () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 $_p9k_color1 yellow MIDNIGHT_COMMANDER_ICON 0 '' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_nix_shell () {
	_p9k_prompt_segment $0 4 $_p9k_color1 NIX_SHELL_ICON 0 '' "${(M)IN_NIX_SHELL:#(pure|impure)}"
}
prompt_nnn () {
	_p9k_prompt_segment $0 6 $_p9k_color1 NNN_ICON 0 '' $NNNLVL
}
prompt_node_version () {
	_p9k_upglob package.json -.
	local -i idx=$? 
	(( idx || ! _POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY )) || return
	local node=$commands[node] 
	local -a file_deps env_deps
	if [[ $node == ${NODENV_ROOT:-$HOME/.nodenv}/shims/node ]]
	then
		env_deps+=("$NODENV_VERSION") 
		file_deps+=(${NODENV_ROOT:-$HOME/.nodenv}/version) 
		if [[ $NODENV_DIR != (|.) ]]
		then
			[[ $NODENV_DIR == /* ]] && local dir=$NODENV_DIR  || local dir="$_p9k__cwd_a/$NODENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if [[ -e $dir/.node-version ]]
					then
						file_deps+=($dir/.node-version) 
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		_p9k_upglob .node-version -. || file_deps+=($_p9k__parent_dirs[idx]/.node-version) 
	elif (( idx ))
	then
		file_deps+=($_p9k__parent_dirs[idx]/package.json) 
	fi
	if ! _p9k_cache_stat_get "$0 $#env_deps ${(j: :)${(@q)env_deps}} ${(j: :)${(@q)file_deps}}" $file_deps $node
	then
		local out
		out=$($node --version 2>/dev/null) 
		_p9k_cache_stat_set $(( ! $? )) "$out"
	fi
	(( $_p9k__cache_val[1] )) || return
	local v=$_p9k__cache_val[2] 
	[[ $v == v?* ]] || return
	_p9k_prompt_segment "$0" "green" "white" 'NODE_ICON' 0 '' "${${v#v}//\%/%%}"
}
prompt_nodeenv () {
	local msg
	if (( _POWERLEVEL9K_NODEENV_SHOW_NODE_VERSION )) && _p9k_cached_cmd 0 '' node --version
	then
		msg="${_p9k__ret//\%/%%} " 
	fi
	msg+="$_POWERLEVEL9K_NODEENV_LEFT_DELIMITER${${NODE_VIRTUAL_ENV:t}//\%/%%}$_POWERLEVEL9K_NODEENV_RIGHT_DELIMITER" 
	_p9k_prompt_segment "$0" "black" "green" 'NODE_ICON' 0 '' "$msg"
}
prompt_nodenv () {
	if [[ -n $NODENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_NODENV_SOURCES[(I)shell]} )) || return
		local v=$NODENV_VERSION 
	else
		(( ${_POWERLEVEL9K_NODENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $NODENV_DIR != (|.) ]]
		then
			[[ $NODENV_DIR == /* ]] && local dir=$NODENV_DIR  || local dir="$_p9k__cwd_a/$NODENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.node-version
					then
						(( ${_POWERLEVEL9K_NODENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .node-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.node-version
			then
				(( ${_POWERLEVEL9K_NODENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_NODENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_NODENV_SOURCES[(I)global]} )) || return
			_p9k_nodenv_global_version
		fi
		_p9k_nodeenv_version_transform $_p9k__ret || return
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_NODENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_nodenv_global_version
		_p9k_nodeenv_version_transform $_p9k__ret && [[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_NODENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "black" "green" 'NODE_ICON' 0 '' "${v//\%/%%}"
}
prompt_nordvpn () {
	return
	unset $__p9k_nordvpn_tag P9K_NORDVPN_COUNTRY_CODE
	[[ -e /run/nordvpn/nordvpnd.sock ]] || return
	_p9k_fetch_nordvpn_status 2> /dev/null || return
	if [[ $P9K_NORDVPN_SERVER == (#b)([[:alpha:]]##)[[:digit:]]##.nordvpn.com ]]
	then
		typeset -g P9K_NORDVPN_COUNTRY_CODE=${${(U)match[1]}//İ/I} 
	fi
	case $P9K_NORDVPN_STATUS in
		(Connected) _p9k_prompt_segment $0_CONNECTED blue white NORDVPN_ICON 0 '' "$P9K_NORDVPN_COUNTRY_CODE" ;;
		(Disconnected | Connecting | Disconnecting) local state=${${(U)P9K_NORDVPN_STATUS}//İ/I} 
			_p9k_get_icon $0_$state FAIL_ICON
			_p9k_prompt_segment $0_$state yellow white NORDVPN_ICON 0 '' "$_p9k__ret" ;;
		(*) return ;;
	esac
}
prompt_nvm () {
	[[ -n $NVM_DIR ]] && _p9k_nvm_ls_current || return
	local current=$_p9k__ret 
	(( _POWERLEVEL9K_NVM_SHOW_SYSTEM )) || [[ $current != system ]] || return
	(( _POWERLEVEL9K_NVM_PROMPT_ALWAYS_SHOW )) || ! _p9k_nvm_ls_default || [[ $_p9k__ret != $current ]] || return
	_p9k_prompt_segment "$0" "magenta" "black" 'NODE_ICON' 0 '' "${${current#v}//\%/%%}"
}
prompt_openfoam () {
	if [[ -z "$WM_FORK" ]]
	then
		_p9k_prompt_segment "$0" "yellow" "$_p9k_color1" '' 0 '' "OF: ${${WM_PROJECT_VERSION:t}//\%/%%}"
	else
		_p9k_prompt_segment "$0" "yellow" "$_p9k_color1" '' 0 '' "F-X: ${${WM_PROJECT_VERSION:t}//\%/%%}"
	fi
}
prompt_os_icon () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "$0" "black" "white" '' 0 '' "$_p9k_os_icon"
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_package () {
	unset P9K_PACKAGE_NAME P9K_PACKAGE_VERSION
	_p9k_upglob package.json -. && return
	local file=$_p9k__parent_dirs[$?]/package.json 
	if ! _p9k_cache_stat_get $0 $file
	then
		() {
			local data field
			local -A found
			{
				data="$(<$file)"  || return
			} 2> /dev/null
			data=${${data//$'\r'}##[[:space:]]#} 
			[[ $data == '{'* ]] || return
			data[1]= 
			local -i depth=1 
			while true
			do
				data=${data##[[:space:]]#} 
				[[ -n $data ]] || return
				case $data[1] in
					('{' | '[') data[1]= 
						(( ++depth )) ;;
					('}' | ']') data[1]= 
						(( --depth > 0 )) || return ;;
					(':') data[1]=  ;;
					(',') data[1]= 
						field=  ;;
					([[:alnum:].]) data=${data##[[:alnum:].]#}  ;;
					('"') local tail=${data##\"([^\"\\]|\\?)#} 
						[[ $tail == '"'* ]] || return
						local s=${data:1:-$#tail} 
						data=${tail:1} 
						(( depth == 1 )) || continue
						if [[ -z $field ]]
						then
							field=${s:-x} 
						elif [[ $field == (name|version) ]]
						then
							(( ! $+found[$field] )) || return
							[[ -n $s ]] || return
							[[ $s != *($'\n'|'\')* ]] || return
							found[$field]=$s 
							(( $#found == 2 )) && break
						fi ;;
					(*) return 1 ;;
				esac
			done
			_p9k_cache_stat_set 1 $found[name] $found[version]
			return 0
		} || _p9k_cache_stat_set 0
	fi
	(( _p9k__cache_val[1] )) || return
	P9K_PACKAGE_NAME=$_p9k__cache_val[2] 
	P9K_PACKAGE_VERSION=$_p9k__cache_val[3] 
	_p9k_prompt_segment "$0" "cyan" "$_p9k_color1" PACKAGE_ICON 0 '' ${P9K_PACKAGE_VERSION//\%/%%}
}
prompt_per_directory_history () {
	if [[ $_per_directory_history_is_global == true ]]
	then
		_p9k_prompt_segment ${0}_GLOBAL 3 $_p9k_color1 HISTORY_ICON 0 '' global
	else
		_p9k_prompt_segment ${0}_LOCAL 5 $_p9k_color1 HISTORY_ICON 0 '' local
	fi
}
prompt_perlbrew () {
	if (( _POWERLEVEL9K_PERLBREW_PROJECT_ONLY ))
	then
		_p9k_upglob 'cpanfile|.perltidyrc|(|MY)META.(yml|json)|(Makefile|Build).PL|*.(pl|pm|t|pod)' -. && return
	fi
	local v=$PERLBREW_PERL 
	(( _POWERLEVEL9K_PERLBREW_SHOW_PREFIX )) || v=${v#*-} 
	[[ -n $v ]] || return
	_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PERL_ICON' 0 '' "${v//\%/%%}"
}
prompt_php_version () {
	if (( _POWERLEVEL9K_PHP_VERSION_PROJECT_ONLY ))
	then
		_p9k_upglob 'composer.json|*.php' -. && return
	fi
	_p9k_cached_cmd 0 '' php --version || return
	[[ $_p9k__ret == (#b)(*$'\n')#'PHP '([[:digit:].]##)* ]] || return
	local v=$match[2] 
	_p9k_prompt_segment "$0" "fuchsia" "grey93" 'PHP_ICON' 0 '' "${v//\%/%%}"
}
prompt_phpenv () {
	if [[ -n $PHPENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_PHPENV_SOURCES[(I)shell]} )) || return
		local v=$PHPENV_VERSION 
	else
		(( ${_POWERLEVEL9K_PHPENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $PHPENV_DIR != (|.) ]]
		then
			[[ $PHPENV_DIR == /* ]] && local dir=$PHPENV_DIR  || local dir="$_p9k__cwd_a/$PHPENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.php-version
					then
						(( ${_POWERLEVEL9K_PHPENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .php-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.php-version
			then
				(( ${_POWERLEVEL9K_PHPENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_PHPENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_PHPENV_SOURCES[(I)global]} )) || return
			_p9k_phpenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_PHPENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_phpenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_PHPENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "magenta" "$_p9k_color1" 'PHP_ICON' 0 '' "${v//\%/%%}"
}
prompt_plenv () {
	if [[ -n $PLENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_PLENV_SOURCES[(I)shell]} )) || return
		local v=$PLENV_VERSION 
	else
		(( ${_POWERLEVEL9K_PLENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $PLENV_DIR != (|.) ]]
		then
			[[ $PLENV_DIR == /* ]] && local dir=$PLENV_DIR  || local dir="$_p9k__cwd_a/$PLENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.perl-version
					then
						(( ${_POWERLEVEL9K_PLENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .perl-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.perl-version
			then
				(( ${_POWERLEVEL9K_PLENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_PLENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_PLENV_SOURCES[(I)global]} )) || return
			_p9k_plenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_PLENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_plenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_PLENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PERL_ICON' 0 '' "${v//\%/%%}"
}
prompt_powerlevel9k_setup () {
	_p9k_restore_special_params
	eval "$__p9k_intro"
	_p9k_setup
}
prompt_powerlevel9k_teardown () {
	_p9k_restore_special_params
	eval "$__p9k_intro"
	add-zsh-hook -D precmd '(_p9k_|powerlevel9k_)*'
	add-zsh-hook -D preexec '(_p9k_|powerlevel9k_)*'
	PROMPT='%m%# ' 
	RPROMPT= 
	if (( __p9k_enabled ))
	then
		_p9k_deinit
		__p9k_enabled=0 
	fi
}
prompt_prompt_char () {
	local saved=$_p9k__prompt_char_saved[$_p9k__prompt_side$_p9k__segment_index$((!_p9k__status))] 
	if [[ -n $saved ]]
	then
		_p9k__prompt+=$saved 
		return
	fi
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	if (( __p9k_sh_glob ))
	then
		if (( _p9k__status ))
		then
			if (( _POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE ))
			then
				_p9k_prompt_segment $0_ERROR_VIINS "$_p9k_color1" 196 '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*overwrite*}}' '❯'
				_p9k_prompt_segment $0_ERROR_VIOWR "$_p9k_color1" 196 '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*insert*}}' '▶'
			else
				_p9k_prompt_segment $0_ERROR_VIINS "$_p9k_color1" 196 '' 0 '${${${${_p9k__keymap:#vicmd}:#vivis}:#vivli}}' '❯'
			fi
			_p9k_prompt_segment $0_ERROR_VICMD "$_p9k_color1" 196 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' '❮'
			_p9k_prompt_segment $0_ERROR_VIVIS "$_p9k_color1" 196 '' 0 '${$((! ${#${${${${:-$_p9k__keymap$_p9k__region_active}:#vicmd1}:#vivis?}:#vivli?}})):#0}' 'Ⅴ'
		else
			if (( _POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE ))
			then
				_p9k_prompt_segment $0_OK_VIINS "$_p9k_color1" 76 '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*overwrite*}}' '❯'
				_p9k_prompt_segment $0_OK_VIOWR "$_p9k_color1" 76 '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*insert*}}' '▶'
			else
				_p9k_prompt_segment $0_OK_VIINS "$_p9k_color1" 76 '' 0 '${${${${_p9k__keymap:#vicmd}:#vivis}:#vivli}}' '❯'
			fi
			_p9k_prompt_segment $0_OK_VICMD "$_p9k_color1" 76 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' '❮'
			_p9k_prompt_segment $0_OK_VIVIS "$_p9k_color1" 76 '' 0 '${$((! ${#${${${${:-$_p9k__keymap$_p9k__region_active}:#vicmd1}:#vivis?}:#vivli?}})):#0}' 'Ⅴ'
		fi
	else
		if (( _p9k__status ))
		then
			if (( _POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE ))
			then
				_p9k_prompt_segment $0_ERROR_VIINS "$_p9k_color1" 196 '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*overwrite*)}' '❯'
				_p9k_prompt_segment $0_ERROR_VIOWR "$_p9k_color1" 196 '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*insert*)}' '▶'
			else
				_p9k_prompt_segment $0_ERROR_VIINS "$_p9k_color1" 196 '' 0 '${_p9k__keymap:#(vicmd|vivis|vivli)}' '❯'
			fi
			_p9k_prompt_segment $0_ERROR_VICMD "$_p9k_color1" 196 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' '❮'
			_p9k_prompt_segment $0_ERROR_VIVIS "$_p9k_color1" 196 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#(vicmd1|vivis?|vivli?)}' 'Ⅴ'
		else
			if (( _POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE ))
			then
				_p9k_prompt_segment $0_OK_VIINS "$_p9k_color1" 76 '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*overwrite*)}' '❯'
				_p9k_prompt_segment $0_OK_VIOWR "$_p9k_color1" 76 '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*insert*)}' '▶'
			else
				_p9k_prompt_segment $0_OK_VIINS "$_p9k_color1" 76 '' 0 '${_p9k__keymap:#(vicmd|vivis|vivli)}' '❯'
			fi
			_p9k_prompt_segment $0_OK_VICMD "$_p9k_color1" 76 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' '❮'
			_p9k_prompt_segment $0_OK_VIVIS "$_p9k_color1" 76 '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#(vicmd1|vivis?|vivli?)}' 'Ⅴ'
		fi
	fi
	(( _p9k__has_upglob )) || _p9k__prompt_char_saved[$_p9k__prompt_side$_p9k__segment_index$((!_p9k__status))]=$_p9k__prompt[len+1,-1] 
}
prompt_proxy () {
	local -U p=($all_proxy $http_proxy $https_proxy $ftp_proxy $ALL_PROXY $HTTP_PROXY $HTTPS_PROXY $FTP_PROXY) 
	p=(${(@)${(@)${(@)p#*://}##*@}%%/*}) 
	(( $#p == 1 )) || p=("") 
	_p9k_prompt_segment $0 $_p9k_color1 blue PROXY_ICON 0 '' "$p[1]"
}
prompt_public_ip () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	local ip='${_p9k__public_ip:-$_POWERLEVEL9K_PUBLIC_IP_NONE}' 
	if [[ -n $_POWERLEVEL9K_PUBLIC_IP_VPN_INTERFACE ]]
	then
		_p9k_prompt_segment "$0" "$_p9k_color1" "$_p9k_color2" PUBLIC_IP_ICON 1 '${_p9k__public_ip_not_vpn:+'$ip'}' $ip
		_p9k_prompt_segment "$0" "$_p9k_color1" "$_p9k_color2" VPN_ICON 1 '${_p9k__public_ip_vpn:+'$ip'}' $ip
	else
		_p9k_prompt_segment "$0" "$_p9k_color1" "$_p9k_color2" PUBLIC_IP_ICON 1 $ip $ip
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_pyenv () {
	_p9k_pyenv_compute || return
	_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PYTHON_ICON' 0 '' "${_p9k__pyenv_version//\%/%%}"
}
prompt_ram () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 yellow "$_p9k_color1" RAM_ICON 1 '$_p9k__ram_free' '$_p9k__ram_free'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_ranger () {
	_p9k_prompt_segment $0 $_p9k_color1 yellow RANGER_ICON 0 '' $RANGER_LEVEL
}
prompt_rbenv () {
	if [[ -n $RBENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_RBENV_SOURCES[(I)shell]} )) || return
		local v=$RBENV_VERSION 
	else
		(( ${_POWERLEVEL9K_RBENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $RBENV_DIR != (|.) ]]
		then
			[[ $RBENV_DIR == /* ]] && local dir=$RBENV_DIR  || local dir="$_p9k__cwd_a/$RBENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.ruby-version
					then
						(( ${_POWERLEVEL9K_RBENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .ruby-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.ruby-version
			then
				(( ${_POWERLEVEL9K_RBENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_RBENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_RBENV_SOURCES[(I)global]} )) || return
			_p9k_rbenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_RBENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_rbenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_RBENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "red" "$_p9k_color1" 'RUBY_ICON' 0 '' "${v//\%/%%}"
}
prompt_root_indicator () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "$0" "$_p9k_color1" "yellow" 'ROOT_ICON' 0 '${${(%):-%#}:#\%}' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_rspec_stats () {
	if [[ -d app && -d spec ]]
	then
		local -a code=(app/**/*.rb(N)) 
		(( $#code )) || return
		local tests=(spec/**/*.rb(N)) 
		_p9k_build_test_stats "$0" "$#code" "$#tests" "RSpec" 'TEST_ICON'
	fi
}
prompt_rust_version () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 darkorange $_p9k_color1 RUST_ICON 1 '$P9K_RUST_VERSION' '${P9K_RUST_VERSION//\%/%%}'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_rvm () {
	[[ $GEM_HOME == *rvm* && $ruby_string != $rvm_path/bin/ruby ]] || return
	local v=${GEM_HOME:t} 
	(( _POWERLEVEL9K_RVM_SHOW_GEMSET )) || v=${v%%${rvm_gemset_separator:-@}*} 
	(( _POWERLEVEL9K_RVM_SHOW_PREFIX )) || v=${v#*-} 
	[[ -n $v ]] || return
	_p9k_prompt_segment "$0" "240" "$_p9k_color1" 'RUBY_ICON' 0 '' "${v//\%/%%}"
}
prompt_scalaenv () {
	if [[ -n $SCALAENV_VERSION ]]
	then
		(( ${_POWERLEVEL9K_SCALAENV_SOURCES[(I)shell]} )) || return
		local v=$SCALAENV_VERSION 
	else
		(( ${_POWERLEVEL9K_SCALAENV_SOURCES[(I)local|global]} )) || return
		_p9k__ret= 
		if [[ $SCALAENV_DIR != (|.) ]]
		then
			[[ $SCALAENV_DIR == /* ]] && local dir=$SCALAENV_DIR  || local dir="$_p9k__cwd_a/$SCALAENV_DIR" 
			dir=${dir:A} 
			if [[ $dir != $_p9k__cwd_a ]]
			then
				while true
				do
					if _p9k_read_word $dir/.scala-version
					then
						(( ${_POWERLEVEL9K_SCALAENV_SOURCES[(I)local]} )) || return
						break
					fi
					[[ $dir == (/|.) ]] && break
					dir=${dir:h} 
				done
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			_p9k_upglob .scala-version -.
			local -i idx=$? 
			if (( idx )) && _p9k_read_word $_p9k__parent_dirs[idx]/.scala-version
			then
				(( ${_POWERLEVEL9K_SCALAENV_SOURCES[(I)local]} )) || return
			else
				_p9k__ret= 
			fi
		fi
		if [[ -z $_p9k__ret ]]
		then
			(( _POWERLEVEL9K_SCALAENV_PROMPT_ALWAYS_SHOW )) || return
			(( ${_POWERLEVEL9K_SCALAENV_SOURCES[(I)global]} )) || return
			_p9k_scalaenv_global_version
		fi
		local v=$_p9k__ret 
	fi
	if (( !_POWERLEVEL9K_SCALAENV_PROMPT_ALWAYS_SHOW ))
	then
		_p9k_scalaenv_global_version
		[[ $v == $_p9k__ret ]] && return
	fi
	if (( !_POWERLEVEL9K_SCALAENV_SHOW_SYSTEM ))
	then
		[[ $v == system ]] && return
	fi
	_p9k_prompt_segment "$0" "red" "$_p9k_color1" 'SCALA_ICON' 0 '' "${v//\%/%%}"
}
prompt_ssh () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "$0" "$_p9k_color1" "yellow" 'SSH_ICON' 0 '' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_status () {
	if ! _p9k_cache_get $0 $_p9k__status $_p9k__pipestatus
	then
		(( _p9k__status )) && local state=ERROR  || local state=OK 
		if (( _POWERLEVEL9K_STATUS_EXTENDED_STATES ))
		then
			if (( _p9k__status ))
			then
				if (( $#_p9k__pipestatus > 1 ))
				then
					state+=_PIPE 
				elif (( _p9k__status > 128 ))
				then
					state+=_SIGNAL 
				fi
			elif [[ "$_p9k__pipestatus" == *[1-9]* ]]
			then
				state+=_PIPE 
			fi
		fi
		_p9k__cache_val=(:) 
		if (( _POWERLEVEL9K_STATUS_$state ))
		then
			if (( _POWERLEVEL9K_STATUS_SHOW_PIPESTATUS ))
			then
				local text=${(j:|:)${(@)_p9k__pipestatus:/(#b)(*)/$_p9k_exitcode2str[$match[1]+1]}} 
			else
				local text=$_p9k_exitcode2str[_p9k__status+1] 
			fi
			if (( _p9k__status ))
			then
				if (( !_POWERLEVEL9K_STATUS_CROSS && _POWERLEVEL9K_STATUS_VERBOSE ))
				then
					_p9k__cache_val=($0_$state red yellow1 CARRIAGE_RETURN_ICON 0 '' "$text") 
				else
					_p9k__cache_val=($0_$state $_p9k_color1 red FAIL_ICON 0 '' '') 
				fi
			elif (( _POWERLEVEL9K_STATUS_VERBOSE || _POWERLEVEL9K_STATUS_OK_IN_NON_VERBOSE ))
			then
				[[ $state == OK ]] && text='' 
				_p9k__cache_val=($0_$state "$_p9k_color1" green OK_ICON 0 '' "$text") 
			fi
		fi
		if (( $#_p9k__pipestatus < 3 ))
		then
			_p9k_cache_set "${(@)_p9k__cache_val}"
		fi
	fi
	_p9k_prompt_segment "${(@)_p9k__cache_val}"
}
prompt_swap () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 yellow "$_p9k_color1" SWAP_ICON 1 '$_p9k__swap_used' '$_p9k__swap_used'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_swift_version () {
	_p9k_cached_cmd 0 '' swift --version || return
	[[ $_p9k__ret == (#b)[^[:digit:]]#([[:digit:].]##)* ]] || return
	_p9k_prompt_segment "$0" "magenta" "white" 'SWIFT_ICON' 0 '' "${match[1]//\%/%%}"
}
prompt_symfony2_tests () {
	if [[ -d src && -d app && -f app/AppKernel.php ]]
	then
		local -a all=(src/**/*.php(N)) 
		local -a code=(${(@)all##*Tests*}) 
		(( $#code )) || return
		_p9k_build_test_stats "$0" "$#code" "$(($#all - $#code))" "SF2" 'TEST_ICON'
	fi
}
prompt_symfony2_version () {
	if [[ -r app/bootstrap.php.cache ]]
	then
		local v="${$(grep -F " VERSION " app/bootstrap.php.cache 2>/dev/null)//[![:digit:].]}" 
		_p9k_prompt_segment "$0" "grey35" "$_p9k_color1" 'SYMFONY_ICON' 0 '' "${v//\%/%%}"
	fi
}
prompt_taskwarrior () {
	unset P9K_TASKWARRIOR_PENDING_COUNT P9K_TASKWARRIOR_OVERDUE_COUNT
	if ! _p9k_taskwarrior_check_data
	then
		_p9k_taskwarrior_data_files=() 
		_p9k_taskwarrior_data_non_files=() 
		_p9k_taskwarrior_data_sig= 
		_p9k_taskwarrior_counters=() 
		_p9k_taskwarrior_next_due=0 
		_p9k_taskwarrior_check_meta || _p9k_taskwarrior_init_meta || return
		_p9k_taskwarrior_init_data
	fi
	(( $#_p9k_taskwarrior_counters )) || return
	local text c=$_p9k_taskwarrior_counters[OVERDUE] 
	if [[ -n $c ]]
	then
		typeset -g P9K_TASKWARRIOR_OVERDUE_COUNT=$c 
		text+="!$c" 
	fi
	c=$_p9k_taskwarrior_counters[PENDING] 
	if [[ -n $c ]]
	then
		typeset -g P9K_TASKWARRIOR_PENDING_COUNT=$c 
		[[ -n $text ]] && text+='/' 
		text+=$c 
	fi
	[[ -n $text ]] || return
	_p9k_prompt_segment $0 6 $_p9k_color1 TASKWARRIOR_ICON 0 '' $text
}
prompt_terraform () {
	local ws=$TF_WORKSPACE 
	if [[ -z $TF_WORKSPACE ]]
	then
		_p9k_read_word ${${TF_DATA_DIR:-.terraform}:A}/environment && ws=$_p9k__ret 
	fi
	[[ -z $ws || ( $ws == default && $_POWERLEVEL9K_TERRAFORM_SHOW_DEFAULT == 0 ) ]] && return
	local pat class state
	for pat class in "${_POWERLEVEL9K_TERRAFORM_CLASSES[@]}"
	do
		if [[ $ws == ${~pat} ]]
		then
			[[ -n $class ]] && state=_${${(U)class}//İ/I} 
			break
		fi
	done
	_p9k_prompt_segment "$0$state" $_p9k_color1 blue TERRAFORM_ICON 0 '' $ws
}
prompt_terraform_version () {
	local v cfg terraform=${commands[terraform]} 
	_p9k_upglob .terraform-version -. || cfg=$_p9k__parent_dirs[$?]/.terraform-version 
	if _p9k_cache_stat_get $0.$TFENV_TERRAFORM_VERSION $terraform $cfg
	then
		v=$_p9k__cache_val[1] 
	else
		v=${${"$(terraform --version 2>/dev/null)"#Terraform v}%%$'\n'*}  || v= 
		_p9k_cache_stat_set "$v"
	fi
	[[ -n $v ]] || return
	_p9k_prompt_segment $0 $_p9k_color1 blue TERRAFORM_ICON 0 '' ${v//\%/%%}
}
prompt_time () {
	if (( _POWERLEVEL9K_EXPERIMENTAL_TIME_REALTIME ))
	then
		_p9k_prompt_segment "$0" "$_p9k_color2" "$_p9k_color1" "TIME_ICON" 0 '' "$_POWERLEVEL9K_TIME_FORMAT"
	else
		if [[ $_p9k__refresh_reason == precmd ]]
		then
			if [[ $+__p9k_instant_prompt_active == 1 && $__p9k_instant_prompt_time_format == $_POWERLEVEL9K_TIME_FORMAT ]]
			then
				_p9k__time=${__p9k_instant_prompt_time//\%/%%} 
			else
				_p9k__time=${${(%)_POWERLEVEL9K_TIME_FORMAT}//\%/%%} 
			fi
		fi
		if (( _POWERLEVEL9K_TIME_UPDATE_ON_COMMAND ))
		then
			_p9k_escape $_p9k__time
			local t=$_p9k__ret 
			_p9k_escape $_POWERLEVEL9K_TIME_FORMAT
			_p9k_prompt_segment "$0" "$_p9k_color2" "$_p9k_color1" "TIME_ICON" 1 '' "\${_p9k__line_finished-$t}\${_p9k__line_finished+$_p9k__ret}"
		else
			_p9k_prompt_segment "$0" "$_p9k_color2" "$_p9k_color1" "TIME_ICON" 0 '' $_p9k__time
		fi
	fi
}
prompt_timewarrior () {
	local dir
	[[ -n ${dir::=$TIMEWARRIORDB} || -n ${dir::=~/.timewarrior}(#q-/N) ]] || dir=${XDG_DATA_HOME:-~/.local/share}/timewarrior 
	dir+=/data 
	local -a stat
	[[ $dir == $_p9k_timewarrior_dir ]] || _p9k_timewarrior_clear
	if [[ -n $_p9k_timewarrior_file_name ]]
	then
		zstat -A stat +mtime -- $dir $_p9k_timewarrior_file_name 2> /dev/null || stat=() 
		if [[ $stat[1] == $_p9k_timewarrior_dir_mtime && $stat[2] == $_p9k_timewarrior_file_mtime ]]
		then
			if (( $+_p9k_timewarrior_tags ))
			then
				_p9k_prompt_segment $0 grey 255 TIMEWARRIOR_ICON 0 '' "${_p9k_timewarrior_tags//\%/%%}"
			fi
			return
		fi
	fi
	if [[ ! -d $dir ]]
	then
		_p9k_timewarrior_clear
		return
	fi
	_p9k_timewarrior_dir=$dir 
	if [[ $stat[1] != $_p9k_timewarrior_dir_mtime ]]
	then
		local -a files=($dir/<->-<->.data(.N)) 
		if (( ! $#files ))
		then
			if (( $#stat )) || zstat -A stat +mtime -- $dir 2> /dev/null
			then
				_p9k_timewarrior_dir_mtime=$stat[1] 
				_p9k_timewarrior_file_mtime=$stat[1] 
				_p9k_timewarrior_file_name=$dir 
				unset _p9k_timewarrior_tags
				_p9k__state_dump_scheduled=1 
			else
				_p9k_timewarrior_clear
			fi
			return
		fi
		_p9k_timewarrior_file_name=${${(AO)files}[1]} 
	fi
	if ! zstat -A stat +mtime -- $dir $_p9k_timewarrior_file_name 2> /dev/null
	then
		_p9k_timewarrior_clear
		return
	fi
	_p9k_timewarrior_dir_mtime=$stat[1] 
	_p9k_timewarrior_file_mtime=$stat[2] 
	{
		local tail=${${(Af)"$(<$_p9k_timewarrior_file_name)"}[-1]} 
	} 2> /dev/null
	if [[ $tail == (#b)'inc '[^\ ]##(|\ #\#(*)) ]]
	then
		_p9k_timewarrior_tags=${${match[2]## #}%% #} 
		_p9k_prompt_segment $0 grey 255 TIMEWARRIOR_ICON 0 '' "${_p9k_timewarrior_tags//\%/%%}"
	else
		unset _p9k_timewarrior_tags
	fi
	_p9k__state_dump_scheduled=1 
}
prompt_todo () {
	unset P9K_TODO_TOTAL_TASK_COUNT P9K_TODO_FILTERED_TASK_COUNT
	[[ -r $_p9k__todo_file && -x $_p9k__todo_command ]] || return
	if ! _p9k_cache_stat_get $0 $_p9k__todo_file
	then
		local count="$($_p9k__todo_command -p ls | command tail -1)" 
		if [[ $count == (#b)'TODO: '([[:digit:]]##)' of '([[:digit:]]##)' '* ]]
		then
			_p9k_cache_stat_set 1 $match[1] $match[2]
		else
			_p9k_cache_stat_set 0
		fi
	fi
	(( $_p9k__cache_val[1] )) || return
	typeset -gi P9K_TODO_FILTERED_TASK_COUNT=$_p9k__cache_val[2] 
	typeset -gi P9K_TODO_TOTAL_TASK_COUNT=$_p9k__cache_val[3] 
	if (( (P9K_TODO_TOTAL_TASK_COUNT    || !_POWERLEVEL9K_TODO_HIDE_ZERO_TOTAL) &&
        (P9K_TODO_FILTERED_TASK_COUNT || !_POWERLEVEL9K_TODO_HIDE_ZERO_FILTERED) ))
	then
		if (( P9K_TODO_TOTAL_TASK_COUNT == P9K_TODO_FILTERED_TASK_COUNT ))
		then
			local text=$P9K_TODO_TOTAL_TASK_COUNT 
		else
			local text="$P9K_TODO_FILTERED_TASK_COUNT/$P9K_TODO_TOTAL_TASK_COUNT" 
		fi
		_p9k_prompt_segment "$0" "grey50" "$_p9k_color1" 'TODO_ICON' 0 '' "$text"
	fi
}
prompt_toolbox () {
	_p9k_prompt_segment $0 $_p9k_color1 yellow TOOLBOX_ICON 0 '' $P9K_TOOLBOX_NAME
}
prompt_user () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment "${0}_ROOT" "${_p9k_color1}" yellow ROOT_ICON 0 '${${(%):-%#}:#\%}' "$_POWERLEVEL9K_USER_TEMPLATE"
	if [[ -n "$SUDO_COMMAND" ]]
	then
		_p9k_prompt_segment "${0}_SUDO" "${_p9k_color1}" yellow SUDO_ICON 0 '${${(%):-%#}:#\#}' "$_POWERLEVEL9K_USER_TEMPLATE"
	else
		_p9k_prompt_segment "${0}_DEFAULT" "${_p9k_color1}" yellow USER_ICON 0 '${${(%):-%#}:#\#}' "%n"
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_vcs () {
	if (( _p9k_vcs_index && $+GITSTATUS_DAEMON_PID_POWERLEVEL9K ))
	then
		_p9k__prompt+='${(e)_p9k__vcs}' 
		return
	fi
	local -a backends=($_POWERLEVEL9K_VCS_BACKENDS) 
	if (( ${backends[(I)git]} && $+GITSTATUS_DAEMON_PID_POWERLEVEL9K )) && _p9k_vcs_gitstatus
	then
		_p9k_vcs_render && return
		backends=(${backends:#git}) 
	fi
	if (( $#backends ))
	then
		VCS_WORKDIR_DIRTY=false 
		VCS_WORKDIR_HALF_DIRTY=false 
		local current_state="" 
		zstyle ':vcs_info:*' enable ${backends}
		vcs_info
		local vcs_prompt="${vcs_info_msg_0_}" 
		if [[ -n "$vcs_prompt" ]]
		then
			if [[ "$VCS_WORKDIR_DIRTY" == true ]]
			then
				current_state='MODIFIED' 
			else
				if [[ "$VCS_WORKDIR_HALF_DIRTY" == true ]]
				then
					current_state='UNTRACKED' 
				else
					current_state='CLEAN' 
				fi
			fi
			_p9k_prompt_segment "${0}_${${(U)current_state}//İ/I}" "${__p9k_vcs_states[$current_state]}" "$_p9k_color1" "$vcs_visual_identifier" 0 '' "$vcs_prompt"
		fi
	fi
}
prompt_vi_mode () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	if (( __p9k_sh_glob ))
	then
		if (( $+_POWERLEVEL9K_VI_OVERWRITE_MODE_STRING ))
		then
			if [[ -n $_POWERLEVEL9K_VI_INSERT_MODE_STRING ]]
			then
				_p9k_prompt_segment $0_INSERT "$_p9k_color1" blue '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*overwrite*}}' "$_POWERLEVEL9K_VI_INSERT_MODE_STRING"
			fi
			_p9k_prompt_segment $0_OVERWRITE "$_p9k_color1" blue '' 0 '${${${${${${:-$_p9k__keymap.$_p9k__zle_state}:#vicmd.*}:#vivis.*}:#vivli.*}:#*.*insert*}}' "$_POWERLEVEL9K_VI_OVERWRITE_MODE_STRING"
		else
			if [[ -n $_POWERLEVEL9K_VI_INSERT_MODE_STRING ]]
			then
				_p9k_prompt_segment $0_INSERT "$_p9k_color1" blue '' 0 '${${${${_p9k__keymap:#vicmd}:#vivis}:#vivli}}' "$_POWERLEVEL9K_VI_INSERT_MODE_STRING"
			fi
		fi
		if (( $+_POWERLEVEL9K_VI_VISUAL_MODE_STRING ))
		then
			_p9k_prompt_segment $0_NORMAL "$_p9k_color1" white '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' "$_POWERLEVEL9K_VI_COMMAND_MODE_STRING"
			_p9k_prompt_segment $0_VISUAL "$_p9k_color1" white '' 0 '${$((! ${#${${${${:-$_p9k__keymap$_p9k__region_active}:#vicmd1}:#vivis?}:#vivli?}})):#0}' "$_POWERLEVEL9K_VI_VISUAL_MODE_STRING"
		else
			_p9k_prompt_segment $0_NORMAL "$_p9k_color1" white '' 0 '${$((! ${#${${${_p9k__keymap:#vicmd}:#vivis}:#vivli}})):#0}' "$_POWERLEVEL9K_VI_COMMAND_MODE_STRING"
		fi
	else
		if (( $+_POWERLEVEL9K_VI_OVERWRITE_MODE_STRING ))
		then
			if [[ -n $_POWERLEVEL9K_VI_INSERT_MODE_STRING ]]
			then
				_p9k_prompt_segment $0_INSERT "$_p9k_color1" blue '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*overwrite*)}' "$_POWERLEVEL9K_VI_INSERT_MODE_STRING"
			fi
			_p9k_prompt_segment $0_OVERWRITE "$_p9k_color1" blue '' 0 '${${:-$_p9k__keymap.$_p9k__zle_state}:#(vicmd.*|vivis.*|vivli.*|*.*insert*)}' "$_POWERLEVEL9K_VI_OVERWRITE_MODE_STRING"
		else
			if [[ -n $_POWERLEVEL9K_VI_INSERT_MODE_STRING ]]
			then
				_p9k_prompt_segment $0_INSERT "$_p9k_color1" blue '' 0 '${_p9k__keymap:#(vicmd|vivis|vivli)}' "$_POWERLEVEL9K_VI_INSERT_MODE_STRING"
			fi
		fi
		if (( $+_POWERLEVEL9K_VI_VISUAL_MODE_STRING ))
		then
			_p9k_prompt_segment $0_NORMAL "$_p9k_color1" white '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#vicmd0}' "$_POWERLEVEL9K_VI_COMMAND_MODE_STRING"
			_p9k_prompt_segment $0_VISUAL "$_p9k_color1" white '' 0 '${(M)${:-$_p9k__keymap$_p9k__region_active}:#(vicmd1|vivis?|vivli?)}' "$_POWERLEVEL9K_VI_VISUAL_MODE_STRING"
		else
			_p9k_prompt_segment $0_NORMAL "$_p9k_color1" white '' 0 '${(M)_p9k__keymap:#(vicmd|vivis|vivli)}' "$_POWERLEVEL9K_VI_COMMAND_MODE_STRING"
		fi
	fi
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_vim_shell () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 green $_p9k_color1 VIM_ICON 0 '' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_virtualenv () {
	local msg='' 
	if (( _POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION )) && _p9k_python_version
	then
		msg="${_p9k__ret//\%/%%} " 
	fi
	local cfg=$VIRTUAL_ENV/pyvenv.cfg 
	if ! _p9k_cache_stat_get $0 $cfg
	then
		local -a reply
		_p9k_parse_virtualenv_cfg $cfg
		_p9k_cache_stat_set "${reply[@]}"
	fi
	if (( _p9k__cache_val[1] ))
	then
		local v=$_p9k__cache_val[2] 
	else
		local v=${VIRTUAL_ENV:t} 
		if [[ $VIRTUAL_ENV_PROMPT == '('?*') ' && $VIRTUAL_ENV_PROMPT != "($v) " ]]
		then
			v=$VIRTUAL_ENV_PROMPT[2,-3] 
		elif [[ $v == $~_POWERLEVEL9K_VIRTUALENV_GENERIC_NAMES ]]
		then
			v=${VIRTUAL_ENV:h:t} 
		fi
	fi
	msg+="$_POWERLEVEL9K_VIRTUALENV_LEFT_DELIMITER${v//\%/%%}$_POWERLEVEL9K_VIRTUALENV_RIGHT_DELIMITER" 
	case $_POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV in
		(false) _p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PYTHON_ICON' 0 '${(M)${#P9K_PYENV_PYTHON_VERSION}:#0}' "$msg" ;;
		(if-different) _p9k_escape $v
			_p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PYTHON_ICON' 0 '${${:-'$_p9k__ret'}:#$_p9k__pyenv_version}' "$msg" ;;
		(*) _p9k_prompt_segment "$0" "blue" "$_p9k_color1" 'PYTHON_ICON' 0 '' "$msg" ;;
	esac
}
prompt_vpn_ip () {
	typeset -ga _p9k__vpn_ip_segments
	_p9k__vpn_ip_segments+=($_p9k__prompt_side $_p9k__line_index $_p9k__segment_index) 
	local p='${(e)_p9k__vpn_ip_'$_p9k__prompt_side$_p9k__segment_index'}' 
	_p9k__prompt+=$p 
	typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$p
}
prompt_wifi () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 green $_p9k_color1 WIFI_ICON 1 '$_p9k__wifi_on' '$P9K_WIFI_LAST_TX_RATE Mbps'
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_xplr () {
	local -i len=$#_p9k__prompt _p9k__has_upglob 
	_p9k_prompt_segment $0 6 $_p9k_color1 XPLR_ICON 0 '' ''
	(( _p9k__has_upglob )) || typeset -g "_p9k__segment_val_${_p9k__prompt_side}[_p9k__segment_index]"=$_p9k__prompt[len+1,-1]
}
prompt_yazi () {
	_p9k_prompt_segment $0 $_p9k_color1 yellow YAZI_ICON 0 '' $YAZI_LEVEL
}
pskill () {
	local pid
	pid=$(ps aux | tail -n +2 \
    | fzf --height 40% --prompt "Kill Process> " \
        --header "Select process to kill (Ctrl-C to cancel)" \
        --preview "echo {}" | awk '{print $2}')  || return
	if [[ -n "$pid" ]]
	then
		ps -p "$pid" -o pid,ppid,user,%cpu,%mem,etime,cmd
		echo ""
		echo -n "Kill process $pid? (y/N): "
		read answer
		if [[ "$answer" == "y" || "$answer" == "Y" ]]
		then
			kill "$pid" && echo "Killed process $pid" || echo "Failed to kill process $pid"
		else
			echo "Cancelled"
		fi
	fi
}
pspick () {
	local pid
	pid=$(ps aux | tail -n +2 \
    | fzf --height 40% --prompt "Process Details> " \
        --preview "ps -p {2} -o pid,ppid,user,%cpu,%mem,etime,cmd" | awk '{print $2}')  || return
	if [[ -n "$pid" ]]
	then
		ps -p "$pid" -o pid,ppid,user,%cpu,%mem,etime,cmd
		echo "\nEnvironment:"
		batcat "/proc/$pid/environ" 2> /dev/null | tr '\0' '\n' | head -20
	fi
}
pyhelp () {
	local help_content
	help_content=$(cat <<'EOF'
UV (Fast Python Package Manager - Recommended!)
  uv        → uv command
  uvi       → uv init (initialize project)
  uva X     → uv add X (add dependency)
  uvad X    → uv add --dev X (add dev dependency)
  uvr X     → uv remove X
  uvs       → uv sync (sync dependencies)
  uvrun X   → uv run X (run command in project env)
  uvl       → uv lock (update lockfile)
  uvt       → uv tree (show dependency tree)
  uvpy      → uv python (Python version management)
  uvpyi X   → uv python install X (install Python version)
  uvpyl     → uv python list (list Python versions)
  uvvenv    → uv venv (create virtual environment)

UV PIP COMPATIBILITY
  uvpi X    → uv pip install X
  uvpu X    → uv pip uninstall X
  uvpl      → uv pip list
  uvpf      → uv pip freeze
  uvpc X    → uv pip compile X (compile requirements)
  uvps X    → uv pip sync X (sync from requirements)

UV FZF HELPERS
  uvnew X [V]  → create new uv project (default Python 3.12)
  uvrm         → pick package → remove (fzf)
  uvpypick     → pick Python version → install (fzf)
  uvsearch X   → search PyPI → add package
  uvinfo       → show project info + dependency tree
  quvenv [N] [V] → quick uv venv (.venv, Python 3.12 defaults)

POETRY
  po        → poetry
  poi       → poetry install
  poa X     → poetry add X
  poad X    → poetry add --group dev X
  por X     → poetry remove X
  poru X    → poetry run X
  pos       → activate project venv (poetry env)
  pob       → poetry build
  pop       → poetry publish
  pou       → poetry update
  poshow    → poetry show

PIP
  pipi X    → pip install X
  pipu X    → pip install --upgrade X
  pipun X   → pip uninstall X
  pipl      → pip list
  pipf      → pip freeze
  pipfr     → pip freeze > requirements.txt
  pipr      → pip install -r requirements.txt

VIRTUAL ENVIRONMENTS
  venv      → create venv in current directory
  vact      → activate venv
  vdeact    → deactivate
  qvenv [name] → create + activate + upgrade pip

CONDA
  cenv      → conda env list
  cact X    → conda activate X
  cdeact    → conda deactivate
  ccreate X → conda create -n X
  cinfo     → conda info
  clist     → conda list

TESTING
  pyt       → pytest -v
  pytc      → pytest --cov

PYTHON UTILITIES
  py        → python
  ipy       → ipython
  jnb       → jupyter notebook
  jlab      → jupyter lab

FZF UI HELPERS
  cenvpick  → pick conda env → activate
  porm      → pick poetry dep → remove
  pipshow   → pick pip package → show info
  pyrun X   → run python file (auto-activates venv if present)
EOF
) 
	_show_help "Python Tools" "$help_content"
}
pyrun () {
	if [[ -f "venv/bin/activate" ]]
	then
		source venv/bin/activate
	fi
	python "$@"
}
qc () {
	git add -p
	echo -n "Commit message: "
	read msg
	if [[ -n "$msg" ]]
	then
		git commit -m "$msg"
	else
		echo "Commit cancelled (empty message)"
	fi
}
quickbuild () {
	if [[ -f CMakeLists.txt ]]
	then
		echo "CMake project detected"
		cmbuild
	elif [[ -f meson.build ]]
	then
		echo "Meson project detected"
		meson setup build && meson compile -C build
	elif [[ -f configure ]]
	then
		echo "Autotools project detected"
		./configure && make
	elif [[ -f Makefile || -f makefile ]]
	then
		echo "Makefile detected"
		make
	else
		echo "No recognized build system found"
		return 1
	fi
}
quvenv () {
	local name="${1:-.venv}" 
	local python="${2:-3.12}" 
	echo "Creating UV virtual environment: $name (Python $python)"
	uv venv "$name" --python "$python"
	source "$name/bin/activate"
	echo "✓ Virtual environment '$name' activated!"
}
qvenv () {
	local name="${1:-venv}" 
	echo "Creating virtual environment: $name"
	python -m venv "$name"
	source "$name/bin/activate"
	pip install --upgrade pip
	echo "Virtual environment '$name' activated!"
}
randpass () {
	local length="${1:-20}" 
	local chars='A-Za-z0-9!@#$%^&*()_+-=' 
	if [[ "$OSTYPE" == "darwin"* ]]
	then
		LC_ALL=C tr -dc "$chars" < /dev/urandom | head -c "$length"
	else
		tr -dc "$chars" < /dev/urandom | head -c "$length"
	fi
	echo
}
randstr () {
	local length="${1:-32}" 
	local chars="${2:-A-Za-z0-9}" 
	if [[ "$OSTYPE" == "darwin"* ]]
	then
		LC_ALL=C tr -dc "$chars" < /dev/urandom | head -c "$length"
	else
		tr -dc "$chars" < /dev/urandom | head -c "$length"
	fi
	echo
}
remotecert () {
	local host="${1}" 
	local port="${2:-443}" 
	if [[ -z "$host" ]]
	then
		echo "Usage: remotecert <host> [port]"
		return 1
	fi
	echo | openssl s_client -connect "$host:$port" -servername "$host" 2> /dev/null | openssl x509 -noout -text
}
removeempty () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		grep -v '^$'
	else
		grep -v '^$' "$file"
	fi
}
replace () {
	local file="${1}" 
	local search="${2}" 
	local replace="${3}" 
	if [[ -z "$file" || -z "$search" || -z "$replace" ]]
	then
		echo "Usage: replace <file> <search> <replace>"
		return 1
	fi
	sed -i "s/$search/$replace/g" "$file"
	echo "Replaced '$search' with '$replace' in $file"
}
reverselines () {
	local file="${1:--}" 
	tac "$file"
}
sechelp () {
	local help_content
	help_content=$(cat <<'EOF'
SSH KEY MANAGEMENT
  sshkey X      → generate ed25519 key with email X
  sshkeyrsa X   → generate RSA key with email X
  sshlist       → list SSH keys
  sshperms      → fix SSH permissions
  sshcopy X     → copy SSH key to server X
  sshagent      → start SSH agent
  sshadd        → add key to agent
  sshaddlist    → list keys in agent

GPG OPERATIONS
  gpglist       → list public keys
  gpglistsec    → list secret keys
  gpggen        → generate new key pair
  gpgexp X      → export public key X
  gpgimp X      → import key from file X
  gpgenc X Y    → encrypt file X for recipient Y
  gpgdec X      → decrypt file X
  gpgsign X     → sign file X
  gpgver X      → verify signature

OPENSSL
  sslgen        → generate self-signed cert
  sslgenkey X   → generate private key
  sslcheck X    → check certificate X
  ssltest X:Y   → test SSL connection to host:port
  remotecert X  → view remote certificate

HASHING
  checksum X    → SHA256 checksum
  verify X      → verify checksum file

PASSWORD GENERATION
  genpass N     → generate base64 password (N bytes)
  genpass16     → generate 16-byte password
  genpass32     → generate 32-byte password
  randpass [N]  → random password with special chars
  mempass [N]   → memorable password (N words)

HELPERS
  sshkeypick      → pick SSH key → view
  sshkeycopy      → pick SSH key → copy to clipboard
  gpgkeypick      → pick GPG key → view
  gpgexppick      → pick GPG key → export
  gpgencfile X Y  → encrypt file X for recipient Y
  gpgdecfile X    → decrypt file X
  gpgsignfile X   → sign file X
  sshgenkey X [T] → generate SSH key (email X, type T)
  gpggenkey X Y   → generate GPG key (name X, email Y)
  certexpiry X    → check cert expiration
  remotecert X [P]→ check remote cert (port P)
  gencert X [D]   → generate self-signed cert (D days)
  hashfile X [A]  → hash file with algorithm A
  createchecksum X→ create SHA256 checksum file
  verifychecksum X→ verify checksum file
  encfile X       → encrypt file with password
  decfile X       → decrypt file with password
  sshaudit        → audit SSH directory permissions
EOF
) 
	_show_help "Security & Crypto Tools" "$help_content"
}
serve () {
	local port="${1:-8000}" 
	local dir="${2:-.}" 
	echo "Starting HTTP server on port $port serving $dir"
	if command -v python3 > /dev/null 2>&1
	then
		echo "Using Python's http.server"
		python3 -m http.server "$port" --directory "$dir"
	elif command -v python > /dev/null 2>&1
	then
		echo "Using Python's SimpleHTTPServer"
		cd "$dir" && python -m SimpleHTTPServer "$port"
	elif command -v npx > /dev/null 2>&1
	then
		echo "Using Node's http-server"
		npx http-server "$dir" -p "$port"
	else
		echo "No HTTP server available. Install Python or Node.js"
		return 1
	fi
}
sfpick () {
	local svc
	svc=$(systemctl list-units --state=failed --no-pager --no-legend \
    | awk '{print $2}' \
    | fzf --height 40% --prompt "Failed Service> " \
        --preview "systemctl status {} && echo '\n--- LOGS ---\n' && journalctl -u {} --no-pager -n 30")  || return
	echo "=== STATUS ==="
	systemctl status "$svc"
	echo "\n=== LOGS ==="
	journalctl -u "$svc" --no-pager -n 50
}
sjpick () {
	local svc
	svc=$(systemctl list-units --type=service --all --no-pager \
    | awk '/\.service/ {print $1}' \
    | fzf --height 40% --prompt "View Logs> " \
        --preview "journalctl -u {} --no-pager -n 50")  || return
	journalctl -fu "$svc"
}
sshaudit () {
	echo "=== SSH Directory Audit ==="
	echo "\nChecking ~/.ssh permissions..."
	if [[ -d ~/.ssh ]]
	then
		local ssh_perm=$(stat -c "%a" ~/.ssh 2>/dev/null || stat -f "%A" ~/.ssh 2>/dev/null) 
		if [[ "$ssh_perm" != "700" ]]
		then
			echo "⚠ ~/.ssh permissions: $ssh_perm (should be 700)"
		else
			echo "✓ ~/.ssh permissions: $ssh_perm"
		fi
		echo "\nChecking key file permissions..."
		for keyfile in ~/.ssh/id_*
		do
			[[ -f "$keyfile" ]] || continue
			local key_perm=$(stat -c "%a" "$keyfile" 2>/dev/null || stat -f "%A" "$keyfile" 2>/dev/null) 
			if [[ "$keyfile" == *.pub ]]
			then
				if [[ "$key_perm" != "644" ]]
				then
					echo "⚠ $keyfile: $key_perm (should be 644)"
				else
					echo "✓ $keyfile: $key_perm"
				fi
			else
				if [[ "$key_perm" != "600" ]]
				then
					echo "⚠ $keyfile: $key_perm (should be 600)"
				else
					echo "✓ $keyfile: $key_perm"
				fi
			fi
		done
	else
		echo "~/.ssh directory not found"
	fi
}
sshgenkey () {
	local email="${1}" 
	local type="${2:-ed25519}" 
	local file="${3:-~/.ssh/id_${type}}" 
	if [[ -z "$email" ]]
	then
		echo "Usage: sshgenkey <email> [type] [output-file]"
		echo "Types: ed25519 (default), rsa"
		return 1
	fi
	if [[ "$type" == "rsa" ]]
	then
		ssh-keygen -t rsa -b 4096 -C "$email" -f "$file"
	else
		ssh-keygen -t ed25519 -C "$email" -f "$file"
	fi
}
sshkeycopy () {
	local key
	key=$(ls -1 ~/.ssh/*.pub 2>/dev/null \
    | fzf --height 40% --prompt "Copy SSH Key> " \
        --preview "cat {}")  || return
	if command -v xclip > /dev/null 2>&1
	then
		batcat "$key" | xclip -selection clipboard
		echo "Copied to clipboard"
	elif command -v pbcopy > /dev/null 2>&1
	then
		batcat "$key" | pbcopy
		echo "Copied to clipboard"
	else
		echo "Clipboard tool not found. Key content:"
		batcat "$key"
	fi
}
sshkeypick () {
	local key
	key=$(ls -1 ~/.ssh/*.pub 2>/dev/null \
    | fzf --height 40% --prompt "SSH Public Key> " \
        --preview "cat {}")  || return
	batcat "$key"
}
ssrpick () {
	local svc
	svc=$(systemctl list-units --type=service --state=active --no-pager \
    | awk '/\.service/ {print $1}' \
    | fzf --height 40% --prompt "Restart Service> ")  || return
	sudo systemctl restart "$svc"
	systemctl status "$svc"
}
sstpick () {
	local svc
	svc=$(systemctl list-units --type=service --all --no-pager \
    | awk '/\.service/ {print $1}' \
    | fzf --height 40% --prompt "Service> " \
        --preview "systemctl status {}")  || return
	systemctl status "$svc"
}
sstppick () {
	local svc
	svc=$(systemctl list-units --type=service --state=active --no-pager \
    | awk '/\.service/ {print $1}' \
    | fzf --height 40% --prompt "Stop Service> ")  || return
	sudo systemctl stop "$svc"
	systemctl status "$svc"
}
sstrpick () {
	local svc
	svc=$(systemctl list-units --type=service --all --no-pager \
    | awk '/\.service/ {print $1}' \
    | fzf --height 40% --prompt "Start Service> ")  || return
	sudo systemctl start "$svc"
	systemctl status "$svc"
}
syscalls () {
	local pid="${1}" 
	if [[ -z "$pid" ]]
	then
		echo "Usage: syscalls <pid>"
		return 1
	fi
	strace -p "$pid" 2>&1
}
sysdhelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE
  sctl      → systemctl
  sctlu     → systemctl --user

SERVICE CONTROL (SYSTEM)
  sstart X  → sudo systemctl start X
  sstop X   → sudo systemctl stop X
  srestart X→ sudo systemctl restart X
  sreload X → sudo systemctl reload X
  sstatus X → systemctl status X
  senable X → sudo systemctl enable X
  sdisable X→ sudo systemctl disable X

SERVICE CONTROL (USER)
  ustart X  → systemctl --user start X
  ustop X   → systemctl --user stop X
  urestart X→ systemctl --user restart X
  ustatus X → systemctl --user status X
  uenable X → systemctl --user enable X
  udisable X→ systemctl --user disable X

LISTING
  slist     → list all services
  slistall  → list all services (including inactive)
  sfailed   → list failed services
  sactive   → list active services

JOURNALCTL (LOGS)
  jctl      → journalctl
  jf        → journalctl -f (follow)
  jfu X     → journalctl -fu X (follow unit)
  jb        → journalctl -b (current boot)
  je        → journalctl -p err (errors only)

SYSTEM STATE
  sreboot   → sudo systemctl reboot
  spoweroff → sudo systemctl poweroff
  sdaemon   → sudo systemctl daemon-reload
  udaemon   → systemctl --user daemon-reload

FZF UI HELPERS
  sstpick   → pick service → show status
  sstrpick  → pick service → start
  sstppick  → pick service → stop
  ssrpick   → pick service → restart
  sjpick    → pick service → tail logs
  sfpick    → pick failed service → show status + logs
EOF
) 
	_show_help "Systemd Services" "$help_content"
}
syshelp () {
	local help_content
	help_content=$(cat <<'EOF'
PROCESS MANAGEMENT
  psa       → ps aux
  psg X     → ps aux | grep X
  topcpu    → top processes by CPU
  topmem    → top processes by memory
  ht        → htop
  htu       → htop for current user
  htcpu     → htop sorted by CPU
  htmem     → htop sorted by memory

MEMORY INFO
  meminfo   → show memory usage
  memtotal  → total memory
  memused   → used memory
  memfree   → free memory
  swapinfo  → swap usage

DISK USAGE
  df        → disk free -h
  du1       → disk usage depth 1
  dus X     → disk usage summary
  dusort    → largest directories

SYSTEM INFO
  sysinfo   → system information
  kernelv   → kernel version
  osinfo    → OS information
  cpuinfo   → CPU information
  uptime    → system uptime
  load      → load average
  temp      → temperature sensors

USERS
  users     → who is logged in
  userlist  → list all users
  lastlogin → last login times

HARDWARE
  lsblk     → list block devices
  lspci     → list PCI devices
  lsusb     → list USB devices
  lsmod     → list kernel modules

LOGS
  dmesg         → kernel messages
  dmesg-err     → kernel errors
  dmesg-warn    → kernel warnings
  dmesg-tail    → last 50 messages

FZF UI HELPERS
  killpick      → pick process → kill
  kill9pick     → pick process → force kill
  pspick        → pick process → view details
  umountpick    → pick mount → unmount
  bigdirs [X] [N]  → show N largest directories in X
  bigfiles [X] [N] → show N largest files in X
  sysmon [N]    → monitor system (refresh every N seconds)
  iostats       → disk I/O statistics
  netiostat     → network I/O statistics (sar)
  sysreport     → full system report
  myptree       → process tree for current user
  openfiles X   → show open files for PID X
  whatport X    → show what's using port X
  cleancache    → clean package manager cache
  zombies       → find zombie processes
  syscalls X    → trace system calls for PID X
EOF
) 
	_show_help "System Management" "$help_content"
}
sysmon () {
	local interval="${1:-2}" 
	watch -n "$interval" 'echo "=== CPU ==="; mpstat 1 1 2>/dev/null || uptime; echo ""; echo "=== Memory ==="; free -h; echo ""; echo "=== Disk ==="; df -h; echo ""; echo "=== Top Processes ==="; ps aux --sort=-%cpu | head -6'
}
sysreport () {
	batcat <<EOF

===================  SYSTEM REPORT  ===================

SYSTEM INFO
$(uname -a)
$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME)

UPTIME
$(uptime)

CPU INFO
$(lscpu | grep -E "Model name|CPU\(s\)|Thread|MHz")

MEMORY
$(free -h | grep -E "Mem|Swap")

DISK USAGE
$(df -h | grep -v tmpfs | grep -v devtmpfs)

LOAD AVERAGE (1m, 5m, 15m)
$(cat /proc/loadavg | awk '{print $1, $2, $3}')

TOP PROCESSES (CPU)
$(ps aux --sort=-%cpu | head -6)

TOP PROCESSES (MEM)
$(ps aux --sort=-%mem | head -6)

=======================================================

EOF
}
texthelp () {
	local help_content
	help_content=$(cat <<'EOF'
GREP
  gr        → grep
  gri       → grep -i (case insensitive)
  grr       → grep -r (recursive)
  grn       → grep -n (with line numbers)
  grepv     → grep -v (invert match)
  grepc     → grep -c (count)
  grl       → grep -l (files with matches)

RIPGREP
  rg        → rg --smart-case
  rgi       → rg -i (case insensitive)
  rgl       → rg -l (files with matches)
  rgt X Y   → rg --type X Y (search by file type)

SED
  sedr      → sed -r (extended regex)
  sedi      → sed -i (in-place edit)

AWK
  awkf      → awk -F (field separator)
  awk1/2/3  → print field 1/2/3
  awkl      → print last field

SORT & UNIQ
  sortn     → sort -n (numeric)
  sortr     → sort -r (reverse)
  sortu     → sort -u (unique)
  uniqc     → uniq -c (count)
  uniqd     → uniq -d (only duplicates)

HEAD & TAIL
  h10/h20   → head -n 10/20
  t10/t20   → tail -n 10/20
  tailf     → tail -f (follow)

JSON (jq)
  jqr       → jq -r (raw output)
  jqc       → jq -c (compact)
  jqs       → jq -S (sort keys)
  jqkeys    → show keys
  jqvalues  → show values

DIFF
  diffc     → diff --color
  diffu     → diff -u (unified)
  diffy     → diff -y (side-by-side)

FZF HELPERS
  linepick X        → pick line from file X
  greppick X [Y]    → interactive grep with preview
  jqexplore X       → explore JSON paths in file X
  replace X Y Z     → replace Y with Z in file X
  countpattern X Y  → count occurrences of X in Y
  csvcolumn X Y     → extract column X from CSV file Y
  jsonpretty [X]    → pretty print JSON
  jsonminify [X]    → minify JSON
  json2yaml [X]     → convert JSON to YAML
  yaml2json [X]     → convert YAML to JSON
  extractemails [X] → extract email addresses
  extracturls [X]   → extract URLs
  dedup [X]         → remove duplicate lines
  toplines [N] [X]  → show N most common lines
  wordfreq [X]      → word frequency counter
  removeempty [X]   → remove empty lines
  addlinenums [X]   → add line numbers
  reverselines [X]  → reverse line order
  colstats [N] [X]  → column statistics
EOF
) 
	_show_help "Text Processing" "$help_content"
}
tfhelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE COMMANDS
  tf        → terraform
  tfi       → terraform init
  tfp       → terraform plan
  tfa       → terraform apply
  tfd       → terraform destroy
  tfv       → terraform validate
  tff       → terraform fmt
  tfo       → terraform output
  tfs       → terraform show

WORKSPACES
  tfw       → terraform workspace
  tfwl      → list workspaces
  tfws X    → select workspace X
  tfwn X    → create new workspace X

STATE MANAGEMENT
  tfsl      → terraform state list
  tfss X    → terraform state show X
  tfsrm X   → terraform state rm X

PLAN + APPLY WORKFLOW
  tfpa      → plan -out=tfplan
  tfaa      → apply tfplan

FZF UI HELPERS
  tfwpick   → pick workspace → switch
  tfrpick   → pick resource → show state
  tfrmpick  → pick resource → remove from state
  tfquick   → plan → prompt → apply
EOF
) 
	_show_help "Terraform Infrastructure" "$help_content"
}
tfquick () {
	echo "Running terraform plan..."
	terraform plan -out=tfplan || return
	echo ""
	read "?Apply this plan? (y/N): " answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		terraform apply tfplan
		rm -f tfplan
	else
		echo "Cancelled. Plan saved as tfplan"
	fi
}
tfrmpick () {
	local res
	res=$(terraform state list \
    | fzf --height 40% --prompt "Remove Resource> ")  || return
	echo "Removing $res from state..."
	terraform state rm "$res"
}
tfrpick () {
	local res
	res=$(terraform state list \
    | fzf --height 40% --prompt "Resource> " \
        --preview "terraform state show {}")  || return
	terraform state show "$res"
}
tfwpick () {
	local ws
	ws=$(terraform workspace list | sed 's/[\*\ ]//g' \
    | fzf --height 40% --prompt "Terraform Workspace> ")  || return
	terraform workspace select "$ws"
}
timecmd () {
	if [[ -z "$1" ]]
	then
		echo "Usage: timecmd <command>"
		echo "Example: timecmd 'ls -la'"
		return 1
	fi
	if command -v hyperfine > /dev/null 2>&1
	then
		hyperfine --warmup 3 "$@"
	else
		echo "hyperfine not installed. Using 'time' instead:"
		echo ""
		echo "Installing hyperfine:"
		echo "  cargo install hyperfine"
		echo "  # or"
		echo "  sudo dnf install hyperfine"
		echo ""
		time eval "$@"
	fi
}
timecmp () {
	if [[ -z "$2" ]]
	then
		echo "Usage: timecmp <command1> <command2>"
		echo "Example: timecmp 'grep foo' 'rg foo'"
		return 1
	fi
	if command -v hyperfine > /dev/null 2>&1
	then
		hyperfine --warmup 2 "$1" "$2"
	else
		echo "hyperfine not installed. Using basic timing:"
		echo ""
		echo "Command 1: $1"
		time eval "$1" > /dev/null
		echo ""
		echo "Command 2: $2"
		time eval "$2" > /dev/null
	fi
}
tmcd () {
	local session_name=$(basename "$PWD" | tr '.' '_') 
	if tmux has-session -t "$session_name" 2> /dev/null
	then
		echo "Session '$session_name' already exists. Attaching..."
		if [[ -z "$TMUX" ]]
		then
			tmux attach -t "$session_name"
		else
			tmux switch-client -t "$session_name"
		fi
	else
		tmux new -s "$session_name"
	fi
}
tmhelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE COMMANDS
  tm        → tmux
  tma       → tmux attach (to last session)
  tmat X    → tmux attach -t X
  tmn       → tmux new
  tmns X    → tmux new -s X
  tml       → list sessions
  tmk X     → kill session X
  tmka      → kill all sessions (kill server)

WINDOW/PANE
  tmw       → list windows
  tmp       → list panes

SMART HELPERS
  tms [name]  → attach to session or create if doesn't exist
  tmuxs [name]→ create or switch to session (works inside tmux)
  tmcd        → create/attach session named after current directory
  tmlist      → list all sessions with details

FZF UI HELPERS
  tmpick    → pick session → attach/switch
  tmkpick   → pick session → kill
  tmwpick   → pick window → switch (inside tmux)
EOF
) 
	_show_help "Tmux Terminal Multiplexer" "$help_content"
}
tmkpick () {
	local session
	session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null \
    | fzf --height 40% --prompt "Kill Session> ")  || return
	tmux kill-session -t "$session"
}
tmlist () {
	tmux list-sessions -F "#{session_name} (#{session_windows} windows, created #{session_created_string})"
}
tmpick () {
	local session
	session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null \
    | fzf --height 40% --prompt "Tmux Session> " \
        --preview "tmux list-windows -t {}")  || return
	if [[ -z "$TMUX" ]]
	then
		tmux attach -t "$session"
	else
		tmux switch-client -t "$session"
	fi
}
tmux_smart_attach () {
	local session="${1:-main}" 
	if tmux has-session -t "$session" 2> /dev/null
	then
		tmux attach -t "$session"
	else
		tmux new -s "$session"
	fi
}
tmuxs () {
	local session="${1:-main}" 
	if [[ -z "$TMUX" ]]
	then
		tmux_smart_attach "$session"
	else
		if tmux has-session -t "$session" 2> /dev/null
		then
			tmux switch-client -t "$session"
		else
			echo "Session '$session' does not exist. Create it? (y/N)"
			read answer
			if [[ "$answer" == "y" || "$answer" == "Y" ]]
			then
				tmux new-session -d -s "$session"
				tmux switch-client -t "$session"
			fi
		fi
	fi
}
tmwpick () {
	if [[ -z "$TMUX" ]]
	then
		echo "Not in a tmux session"
		return 1
	fi
	local window
	window=$(tmux list-windows -F "#{window_index}: #{window_name}" \
    | fzf --height 40% --prompt "Switch Window> ")  || return
	local window_id=$(echo "$window" | cut -d: -f1) 
	tmux select-window -t "$window_id"
}
toplines () {
	local n="${1:-10}" 
	local file="${2:--}" 
	sort "$file" | uniq -c | sort -rn | head -n "$n"
}
toppid () {
	local type="${1:-cpu}" 
	case "$type" in
		(cpu) ps aux --sort=-%cpu | head -11 ;;
		(mem | memory) ps aux --sort=-%mem | head -11 ;;
		(*) echo "Usage: toppid [cpu|mem]" ;;
	esac
}
trace () {
	local host="${1:-google.com}" 
	traceroute "$host"
}
umountpick () {
	local mount
	mount=$(mount | awk '{print $3}' | grep -v "^/\(proc\|sys\|dev\)" \
    | fzf --height 40% --prompt "Unmount> " \
        --preview "df -h {}")  || return
	echo "Unmount $mount?"
	read "?Confirm (y/N): " answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		sudo umount "$mount"
	else
		echo "Cancelled"
	fi
}
uvinfo () {
	if [[ ! -f "pyproject.toml" ]]
	then
		echo "No pyproject.toml found"
		return 1
	fi
	echo "=== UV Project Info ==="
	echo ""
	if [[ -f ".python-version" ]]
	then
		echo "Python Version: $(cat .python-version)"
	fi
	echo ""
	echo "=== Dependencies ==="
	uv pip list
	echo ""
	echo "=== Dependency Tree ==="
	uv tree
}
uvnew () {
	local name="${1}" 
	local python_version="${2:-3.12}" 
	if [[ -z "$name" ]]
	then
		echo "Usage: uvnew <project-name> [python-version]"
		echo "Example: uvnew myapp 3.12"
		return 1
	fi
	mkdir -p "$name"
	cd "$name"
	uv init
	uv python pin "$python_version"
	mkdir -p src/"$name" tests
	touch src/"$name"/__init__.py
	uv add --dev pytest ruff mypy
	echo ""
	echo "✓ UV project '$name' created with Python $python_version"
	echo "  Location: $(pwd)"
	echo ""
	echo "Next steps:"
	echo "  uva <package>     # Add a dependency"
	echo "  uvad <package>    # Add a dev dependency"
	echo "  uvrun pytest      # Run tests"
}
uvpypick () {
	local version
	version=$(echo "3.13\n3.12\n3.11\n3.10\n3.9\n3.8" \
    | fzf --height 40% --prompt "Python Version> " \
        --header "Select Python version to install")  || return
	if [[ -n "$version" ]]
	then
		echo "Installing Python $version with uv..."
		uv python install "$version"
	fi
}
uvrm () {
	if [[ ! -f "pyproject.toml" ]]
	then
		echo "No pyproject.toml found. Not a uv project?"
		return 1
	fi
	local pkg
	pkg=$(uv pip list | tail -n +3 | awk '{print $1}' \
    | fzf --height 40% --prompt "Remove Package> " \
        --preview "uv pip show {}")  || return
	if [[ -n "$pkg" ]]
	then
		uv remove "$pkg"
	fi
}
uvsearch () {
	local query="${1}" 
	if [[ -z "$query" ]]
	then
		echo "Usage: uvsearch <package-name>"
		echo "Example: uvsearch requests"
		return 1
	fi
	echo "Searching PyPI for: $query"
	echo ""
	echo -n "Add '$query' to project? (y/N): "
	read answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		uv add "$query"
	fi
}
vapick () {
	local auth
	auth=$(vault auth list -format=json | jq -r 'keys[]' \
    | fzf --height 40% --prompt "Auth Method> ")  || return
	vault auth list -detailed | grep -A 10 "$auth"
}
vaulthelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE OPERATIONS
  v         → vault
  vl        → vault login
  vs        → vault status
  vr X      → vault read X
  vw X      → vault write X
  vls X     → vault list X
  vd X      → vault delete X

KV (KEY-VALUE)
  vkv       → vault kv
  vkvget X  → vault kv get X
  vkvput X  → vault kv put X
  vkvlist X → vault kv list X
  vkvdel X  → vault kv delete X
  vkvmeta   → vault kv metadata

AUTH METHODS
  va        → vault auth
  val       → vault auth list
  vae X     → vault auth enable X
  vad X     → vault auth disable X

SECRETS ENGINES
  vse       → vault secrets
  vsel      → vault secrets list
  vsee X    → vault secrets enable X
  vsed X    → vault secrets disable X
  vsem X Y  → vault secrets move X Y

POLICY
  vp        → vault policy
  vpl       → vault policy list
  vpr X     → vault policy read X
  vpw X Y   → vault policy write X Y
  vpd X     → vault policy delete X

TOKEN
  vt        → vault token
  vtc       → vault token create
  vtl       → vault token lookup
  vtr X     → vault token revoke X
  vtre      → vault token renew

OPERATOR
  vop       → vault operator
  vopi      → vault operator init
  vopu      → vault operator unseal
  vops      → vault operator seal
  vopr      → vault operator rekey

FZF UI HELPERS
  vrpick [X]    → pick secret → read (mount X, default: secret)
  vdpick [X]    → pick secret → delete
  vppick        → pick policy → read
  vapick        → pick auth method → view
  vsepick       → pick secrets engine → view
  vput X Y Z [M]→ quick kv put (path X, key Y, value Z, mount M)
  vget X [M]    → quick kv get
  vgetf X Y [M] → get field Y from path X
  vlistall [X]  → list all secrets recursively
  vtpolicy X    → create token with policy X
  venablekv [X] → enable KV v2 at path X
  vexport X [M] → export secret as env vars
  vpwrite X Y   → write policy X from file Y
  vquickunseal [X] → unseal with keys from file (DEV ONLY)
EOF
) 
	_show_help "HashiCorp Vault" "$help_content"
}
vdpick () {
	local mount="${1:-secret}" 
	local path
	path=$(vault kv list -format=json "$mount" 2>/dev/null | jq -r '.[]' \
    | fzf --height 40% --prompt "Delete Secret> ")  || return
	echo "Delete secret at $mount/$path?"
	read "?Confirm (y/N): " answer
	if [[ "$answer" == "y" || "$answer" == "Y" ]]
	then
		vault kv delete "$mount/$path"
	else
		echo "Cancelled"
	fi
}
venablekv () {
	local path="${1:-secret}" 
	vault secrets enable -path="$path" kv-v2
	echo "Enabled KV v2 at: $path"
}
verifychecksum () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		echo "Usage: verifychecksum <file>"
		return 1
	fi
	if [[ -f "${file}.sha256" ]]
	then
		sha256sum -c "${file}.sha256"
	else
		echo "Checksum file not found: ${file}.sha256"
		return 1
	fi
}
vexport () {
	local path="${1}" 
	local mount="${2:-secret}" 
	if [[ -z "$path" ]]
	then
		echo "Usage: vexport <path> [mount]"
		return 1
	fi
	local data
	data=$(vault kv get -format=json "$mount/$path" | jq -r '.data.data') 
	echo "$data" | jq -r 'to_entries[] | "export \(.key)=\(.value | @sh)"'
}
vgbrpick () {
	local box
	box=$(vagrant box list | fzf --height 40% --prompt "Remove Box> ")  || return
	local box_name=$(echo "$box" | awk '{print $1}') 
	vagrant box remove "$box_name"
}
vgclean () {
	echo "Pruning stale Vagrant global status..."
	vagrant global-status --prune
}
vgdpick () {
	local vm
	vm=$(vagrant global-status --prune | awk 'NR>2 && $0 ~ /running|poweroff|saved/ {print $1, $2, $4, $5}' \
    | fzf --height 40% --prompt "Destroy VM> ")  || return
	local vm_id=$(echo "$vm" | awk '{print $1}') 
	echo "Destroying VM: $vm_id"
	vagrant destroy -f "$vm_id"
}
vget () {
	local path="${1}" 
	local mount="${2:-secret}" 
	if [[ -z "$path" ]]
	then
		echo "Usage: vget <path> [mount]"
		return 1
	fi
	vault kv get "$mount/$path"
}
vgetf () {
	local path="${1}" 
	local field="${2}" 
	local mount="${3:-secret}" 
	if [[ -z "$path" || -z "$field" ]]
	then
		echo "Usage: vgetf <path> <field> [mount]"
		return 1
	fi
	vault kv get -field="$field" "$mount/$path"
}
vghelp () {
	local help_content
	help_content=$(cat <<'EOF'
CORE COMMANDS
  vg        → vagrant
  vgu       → vagrant up
  vgd       → vagrant destroy
  vgs       → vagrant ssh
  vgh       → vagrant halt
  vgr       → vagrant reload
  vgst      → vagrant status
  vgp       → vagrant provision
  vgsus     → vagrant suspend
  vgres     → vagrant resume

BOX MANAGEMENT
  vgb       → vagrant box
  vgbl      → vagrant box list
  vgba X    → vagrant box add X
  vgbr X    → vagrant box remove X
  vgbu      → vagrant box update

PLUGIN MANAGEMENT
  vgpl      → vagrant plugin list
  vgpi X    → vagrant plugin install X
  vgpu X    → vagrant plugin uninstall X
  vgpup     → vagrant plugin update

ADVANCED
  vgdf      → vagrant destroy -f (force)
  vgssh     → vagrant ssh-config
  vgport    → vagrant port
  vgsnap    → vagrant snapshot

FZF UI HELPERS
  vgspick   → pick VM → ssh
  vghpick   → pick running VM → halt
  vgdpick   → pick VM → destroy
  vgbrpick  → pick box → remove
  vgqup     → vagrant up && provision
  vgclean   → prune stale global status
EOF
) 
	_show_help "Vagrant VMs" "$help_content"
}
vghpick () {
	local vm
	vm=$(vagrant global-status --prune | awk 'NR>2 && /running/ {print $1, $2, $4, $5}' \
    | fzf --height 40% --prompt "Halt VM> ")  || return
	local vm_id=$(echo "$vm" | awk '{print $1}') 
	vagrant halt "$vm_id"
}
vgqup () {
	vagrant up && vagrant provision
}
vgspick () {
	local vm
	vm=$(vagrant global-status --prune | awk 'NR>2 && /running|poweroff|saved/ {print $1, $2, $4, $5}' \
    | fzf --height 40% --prompt "Vagrant VM> " \
        --preview "vagrant status {1}")  || return
	local vm_id=$(echo "$vm" | awk '{print $1}') 
	vagrant ssh "$vm_id"
}
vlistall () {
	local mount="${1:-secret}" 
	echo "Listing all secrets in $mount..."
	vault kv list -format=json "$mount" 2> /dev/null | jq -r '.[]'
}
vppick () {
	local policy
	policy=$(vault policy list \
    | fzf --height 40% --prompt "View Policy> " \
        --preview "vault policy read {}")  || return
	vault policy read "$policy"
}
vput () {
	local path="${1}" 
	local key="${2}" 
	local value="${3}" 
	local mount="${4:-secret}" 
	if [[ -z "$path" || -z "$key" || -z "$value" ]]
	then
		echo "Usage: vput <path> <key> <value> [mount]"
		return 1
	fi
	vault kv put "$mount/$path" "$key=$value"
}
vpwrite () {
	local policy_name="${1}" 
	local file="${2}" 
	if [[ -z "$policy_name" || -z "$file" ]]
	then
		echo "Usage: vpwrite <policy-name> <policy-file>"
		return 1
	fi
	vault policy write "$policy_name" "$file"
}
vquickunseal () {
	local keyfile="${1:-unseal-keys.txt}" 
	if [[ ! -f "$keyfile" ]]
	then
		echo "Key file not found: $keyfile"
		return 1
	fi
	echo "WARNING: Only use for dev environments!"
	while read -r key
	do
		vault operator unseal "$key"
	done < "$keyfile"
}
vrpick () {
	local mount="${1:-secret}" 
	local path
	path=$(vault kv list -format=json "$mount" 2>/dev/null | jq -r '.[]' \
    | fzf --height 40% --prompt "Read Secret> " \
        --preview "vault kv get $mount/{}")  || return
	vault kv get "$mount/$path"
}
vsepick () {
	local engine
	engine=$(vault secrets list -format=json | jq -r 'keys[]' \
    | fzf --height 40% --prompt "Secrets Engine> ")  || return
	vault secrets list -detailed | grep -A 10 "$engine"
}
vtpolicy () {
	local policy="${1}" 
	if [[ -z "$policy" ]]
	then
		echo "Usage: vtpolicy <policy-name>"
		return 1
	fi
	vault token create -policy="$policy"
}
watchhl () {
	local interval="${1:-2}" 
	shift
	watch -n "$interval" --color --differences "$@"
}
whatport () {
	local port="${1}" 
	if [[ -z "$port" ]]
	then
		echo "Usage: whatport <port>"
		return 1
	fi
	sudo lsof -i ":$port"
}
wordfreq () {
	local file="${1:--}" 
	tr -cs '[:alnum:]' '\n' < "$file" | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn
}
yaml2json () {
	local file="${1}" 
	if [[ -z "$file" ]]
	then
		yq -o=json .
	else
		yq -o=json . "$file"
	fi
}
zombies () {
	ps aux | awk '{if ($8=="Z") print}'
}
zshaddhistory () {
	local line=${1%%$'\n'} 
	[[ $line =~ (ANTHROPIC_API_KEY|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN|sk-ant-|AKIA) ]] && return 1
	[[ $line =~ ^export.*=.*sk- ]] && return 1
	return 0
}
zshbench () {
	local count="${1:-10}" 
	echo "Running zsh startup benchmark ($count iterations)..."
	echo ""
	local total=0 
	local times=() 
	for i in {1..$count}
	do
		local start=$(date +%s%N) 
		zsh -i -c exit
		local end=$(date +%s%N) 
		local duration=$(( (end - start) / 1000000 )) 
		times+=($duration) 
		total=$((total + duration)) 
		printf "Run %2d: %4d ms\n" "$i" "$duration"
	done
	echo ""
	echo "Average: $((total / count)) ms"
	echo ""
	local min=${times[1]} 
	local max=${times[1]} 
	for time in $times
	do
		((time < min)) && min=$time 
		((time > max)) && max=$time 
	done
	echo "Min: ${min} ms"
	echo "Max: ${max} ms"
}
zshprof () {
	echo "Profiling zsh startup..."
	echo "This will show which parts of your config are slow"
	echo ""
	zsh -i -c 'zmodload zsh/zprof && source ~/.zshrc && zprof | head -30'
}
zshslow () {
	echo "Checking which config files load slowly..."
	echo ""
	if [[ ! -d "$HOME/.dotfiles/zshrc.d" ]]
	then
		echo "No zshrc.d directory found"
		return 1
	fi
	for config in "$HOME/.dotfiles/zshrc.d"/*.zsh
	do
		if [[ -f "$config" ]]
		then
			local start=$(date +%s%N) 
			source "$config"
			local end=$(date +%s%N) 
			local duration=$(( (end - start) / 1000000 )) 
			printf "%4d ms  %s\n" "$duration" "$(basename $config)"
		fi
	done | sort -rn
}
# Shell Options
setopt nohashdirs
setopt histexpiredupsfirst
setopt histfindnodups
setopt histignorealldups
setopt histignoredups
setopt histignorespace
setopt histreduceblanks
setopt histsavenodups
setopt histverify
setopt login
# Aliases
alias -- DELETE='curl -X DELETE'
alias -- GET='curl -X GET'
alias -- HEAD='curl -I'
alias -- OPTIONS='curl -X OPTIONS'
alias -- PATCH='curl -X PATCH'
alias -- POST='curl -X POST'
alias -- PUT='curl -X PUT'
alias -- acconf='./autogen.sh && ./configure'
alias -- acinstall='./configure && make && sudo make install'
alias -- acmake='./configure && make'
alias -- addroute='sudo ip route add'
alias -- ans=ansible
alias -- ansc=ansible-config
alias -- anscmd='ansible all -a'
alias -- ansd=ansible-doc
alias -- ansg=ansible-galaxy
alias -- ansgcl='ansible-galaxy collection list'
alias -- ansgcr='ansible-galaxy collection install'
alias -- ansgi='ansible-galaxy install'
alias -- ansgl='ansible-galaxy list'
alias -- ansgr='ansible-galaxy remove'
alias -- ansgs='ansible-galaxy search'
alias -- ansi=ansible-inventory
alias -- ansig='ansible-inventory --graph'
alias -- ansihost='ansible-inventory --host'
alias -- ansil='ansible-inventory --list'
alias -- ansp=ansible-playbook
alias -- anspc='ansible-playbook --check --diff'
alias -- anspd='ansible-playbook --check'
alias -- ansping='ansible all -m ping'
alias -- anspv='ansible-playbook -v'
alias -- anspvv='ansible-playbook -vv'
alias -- anspvvv='ansible-playbook -vvv'
alias -- anssetup='ansible all -m setup'
alias -- ansv=ansible-vault
alias -- ansvc='ansible-vault create'
alias -- ansvd='ansible-vault decrypt'
alias -- ansve='ansible-vault encrypt'
alias -- ansved='ansible-vault edit'
alias -- ansvr='ansible-vault rekey'
alias -- ansvv='ansible-vault view'
alias -- arp-scan='sudo arp-scan --localnet'
alias -- arp-table='ip neigh'
alias -- awec2='aws ec2'
alias -- awec2d='aws ec2 describe-instances'
alias -- awec2s='aws ec2 describe-security-groups'
alias -- awec2v='aws ec2 describe-vpcs'
alias -- aweks='aws eks'
alias -- aweksl='aws eks list-clusters'
alias -- awk1='awk "{print \$1}"'
alias -- awk2='awk "{print \$2}"'
alias -- awk3='awk "{print \$3}"'
alias -- awkf='awk -F'
alias -- awkl='awk "{print \$NF}"'
alias -- awscf='aws cloudformation'
alias -- awscfs='aws cloudformation list-stacks'
alias -- awscwl='aws logs'
alias -- awscwlt='aws logs tail --follow'
alias -- awsecs='aws ecs'
alias -- awsecsl='aws ecs list-clusters'
alias -- awsecsls='aws ecs list-services --cluster'
alias -- awsiam='aws iam'
alias -- awsiamr='aws iam list-roles'
alias -- awsiamu='aws iam list-users'
alias -- awsl='aws lambda'
alias -- awslf='aws lambda list-functions'
alias -- awsls=aws
alias -- awss3='aws s3'
alias -- awss3cp='aws s3 cp'
alias -- awss3ls='aws s3 ls'
alias -- awss3sync='aws s3 sync'
alias -- awssm='aws secretsmanager'
alias -- b64dec='base64 -d'
alias -- b64enc=base64
alias -- batt='acpi -b 2>/dev/null'
alias -- battery='upower -i $(upower -e | grep BAT) 2>/dev/null | grep -E "state|percentage|time"'
alias -- blkid='sudo blkid'
alias -- c=consul
alias -- ca='consul agent'
alias -- cacl='consul acl'
alias -- caclp='consul acl policy'
alias -- caclr='consul acl role'
alias -- caclt='consul acl token'
alias -- cact='conda activate'
alias -- cad='consul agent -dev'
alias -- car='consul reload'
alias -- cat=batcat
alias -- ccat='consul catalog'
alias -- ccatd='consul catalog datacenters'
alias -- ccatn='consul catalog nodes'
alias -- ccats='consul catalog services'
alias -- cconf='consul config'
alias -- cconfd='consul config delete'
alias -- cconfl='consul config list'
alias -- cconfr='consul config read'
alias -- cconfw='consul config write'
alias -- ccreate='conda create -n'
alias -- cdeact='conda deactivate'
alias -- ce='consul event'
alias -- cef='consul event fire'
alias -- cel='consul event list'
alias -- cenv='conda env list'
alias -- cg=cargo
alias -- cga='cargo add'
alias -- cgb='cargo build'
alias -- cgbench='cargo bench'
alias -- cgbr='cargo build --release'
alias -- cgc='cargo check'
alias -- cgcl='cargo clean'
alias -- cgcla='cargo clippy -- -W clippy::all'
alias -- cgd='cargo doc'
alias -- cgdo='cargo doc --open'
alias -- cgf='cargo fmt'
alias -- cgfc='cargo fmt -- --check'
alias -- cgi='cargo install'
alias -- cginit='cargo init'
alias -- cgl='cargo clippy'
alias -- cgn='cargo new'
alias -- cgnb='cargo new --bin'
alias -- cgnl='cargo new --lib'
alias -- cgpub='cargo publish'
alias -- cgr='cargo run'
alias -- cgrm='cargo remove'
alias -- cgrr='cargo run --release'
alias -- cgs='cargo search'
alias -- cgt='cargo test'
alias -- cgtr='cargo tree'
alias -- cgu='cargo update'
alias -- cgui='cargo uninstall'
alias -- cgw='cargo watch'
alias -- cgwc='cargo watch -x check'
alias -- cgwr='cargo watch -x run'
alias -- cgwt='cargo watch -x test'
alias -- ch='consul health'
alias -- chc='consul health checks'
alias -- checksum=sha256sum
alias -- chn='consul health node'
alias -- chs='consul health service'
alias -- ci='consul info'
alias -- cinfo='conda info'
alias -- cint='consul intention'
alias -- cintc='consul intention create'
alias -- cintd='consul intention delete'
alias -- cintl='consul intention list'
alias -- cintm='consul intention match'
alias -- cj='consul join'
alias -- ckv='consul kv'
alias -- ckvg='consul kv get'
alias -- ckvl='consul kv delete'
alias -- ckvls='consul kv get -keys '\'\'
alias -- ckvp='consul kv put'
alias -- cl='consul leave'
alias -- clist='conda list'
alias -- cm=cmake
alias -- cmb='cmake --build'
alias -- cmc='cmake --build . --target clean'
alias -- cmconf='cmake -S . -B build'
alias -- cmgen='cmake -G'
alias -- cmi='cmake --install'
alias -- cols='column -s'
alias -- colt='column -t'
alias -- cp=xcp
alias -- cpuinfo=lscpu
alias -- cs='consul services'
alias -- csd='consul services deregister'
alias -- csnap='consul snapshot'
alias -- csnapr='consul snapshot restore'
alias -- csnaps='consul snapshot save'
alias -- csr='consul services register'
alias -- curlL='curl -L'
alias -- curlform='curl -H "Content-Type: application/x-www-form-urlencoded"'
alias -- curli='curl -i'
alias -- curlj='curl -H "Content-Type: application/json"'
alias -- curljson='curl -H "Content-Type: application/json" -H "Accept: application/json"'
alias -- curls='curl -s'
alias -- curlt='curl -w "\n\nTotal time: %{time_total}s\n"'
alias -- curltiming='curl -w "\n\ntime_namelookup: %{time_namelookup}\ntime_connect: %{time_connect}\ntime_appconnect: %{time_appconnect}\ntime_pretransfer: %{time_pretransfer}\ntime_redirect: %{time_redirect}\ntime_starttransfer: %{time_starttransfer}\ntime_total: %{time_total}\n"'
alias -- curlv='curl -v'
alias -- curlx='curl -H "Accept: application/xml"'
alias -- currentuser=whoami
alias -- cut1='cut -f1'
alias -- cut2='cut -f2'
alias -- cut3='cut -f3'
alias -- cutd='cut -d'
alias -- cw='consul watch'
alias -- cwk='consul watch -type=key'
alias -- cwn='consul watch -type=nodes'
alias -- cws='consul watch -type=service'
alias -- dbuild='docker build . -t'
alias -- del='curl -X DELETE'
alias -- delroute='sudo ip route del'
alias -- dexec='docker exec -it'
alias -- df='df -h'
alias -- dfa='df -h -a'
alias -- dft='df -h -t ext4'
alias -- diffc='diff --color=auto'
alias -- diffr='diff -r'
alias -- diffu='diff -u'
alias -- diffy='diff -y'
alias -- diga='dig +short A'
alias -- digaaaa='dig +short AAAA'
alias -- digall='dig +noall +answer'
alias -- digcname='dig +short CNAME'
alias -- digmx='dig +short MX'
alias -- digns='dig +short NS'
alias -- digtrace='dig +trace'
alias -- digtxt='dig +short TXT'
alias -- dim='docker images'
alias -- dima='docker images -a'
alias -- dlog='docker logs -f'
alias -- dmesg='dmesg -T'
alias -- dmesg-err='dmesg -T --level=err'
alias -- dmesg-tail='dmesg -T | tail -50'
alias -- dmesg-warn='dmesg -T --level=warn'
alias -- dnet='docker network ls'
alias -- dnpr='docker network prune'
alias -- dprune='docker system prune -f'
alias -- dpruneall='docker system prune -a -f'
alias -- dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias -- dpsa='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias -- dpull='docker pull'
alias -- drm='docker rm'
alias -- drmi='docker rmi'
alias -- drun='docker run -it --rm'
alias -- dstart='docker start'
alias -- dstop='docker stop'
alias -- du1='du -h --max-depth=1'
alias -- du2='du -h --max-depth=2'
alias -- dus='du -sh'
alias -- dusort='du -h | sort -rh | head'
alias -- dvl='docker volume ls'
alias -- dvp='docker volume prune'
alias -- established='ss -tun | grep ESTAB'
alias -- fwlist='sudo iptables -L -n -v'
alias -- fwlist6='sudo ip6tables -L -n -v'
alias -- g=gh
alias -- g-='git switch -'
alias -- gP='git push'
alias -- ga='git add'
alias -- gb='git branch'
alias -- gc='git commit'
alias -- gca='git commit --amend --no-edit'
alias -- gcal='gcloud auth login'
alias -- gcala='gcloud auth application-default login'
alias -- gcall='gcloud auth list'
alias -- gcalr='gcloud auth login --remote-bootstrap'
alias -- gccc='gcloud config configurations'
alias -- gccl='gcloud config list'
alias -- gccm='gcloud compute'
alias -- gccmi='gcloud compute instances'
alias -- gccmic='gcloud compute instances create'
alias -- gccmid='gcloud compute instances delete'
alias -- gccmil='gcloud compute instances list'
alias -- gccmir='gcloud compute instances reset'
alias -- gccmis='gcloud compute instances start'
alias -- gccmissh='gcloud compute ssh'
alias -- gccmist='gcloud compute instances stop'
alias -- gcconf='gcloud config'
alias -- gccs='gcloud config set'
alias -- gccu='gcloud config unset'
alias -- gcf='git diff --name-only --diff-filter=U'
alias -- gcgke='gcloud container'
alias -- gcgkec='gcloud container clusters create'
alias -- gcgkecreds='gcloud container clusters get-credentials'
alias -- gcgked='gcloud container clusters delete'
alias -- gcgkel='gcloud container clusters list'
alias -- gci='gcloud init'
alias -- gciam='gcloud iam'
alias -- gciamk='gcloud iam service-accounts keys'
alias -- gciaml='gcloud iam service-accounts list'
alias -- gcln='git clean -xdf -i'
alias -- gco='git checkout'
alias -- gcpd='gcloud projects describe'
alias -- gcpl='gcloud projects list'
alias -- gcrun='gcloud run'
alias -- gcrund='gcloud run deploy'
alias -- gcrundel='gcloud run services delete'
alias -- gcrunl='gcloud run services list'
alias -- gcs=gsutil
alias -- gcscp='gsutil cp'
alias -- gcsl='gsutil ls'
alias -- gcsmb='gsutil mb'
alias -- gcsmv='gsutil mv'
alias -- gcsql='gcloud sql'
alias -- gcsqli='gcloud sql instances'
alias -- gcsqlic='gcloud sql instances create'
alias -- gcsqliconn='gcloud sql connect'
alias -- gcsqlid='gcloud sql instances delete'
alias -- gcsqlil='gcloud sql instances list'
alias -- gcsrb='gsutil rb'
alias -- gcsrm='gsutil rm'
alias -- gcsvc='gcloud services'
alias -- gcsvcd='gcloud services disable'
alias -- gcsvce='gcloud services enable'
alias -- gcsvcs='gcloud services list'
alias -- gcsync='gsutil rsync'
alias -- gd='git diff'
alias -- gds='git diff --staged'
alias -- genpass='openssl rand -base64'
alias -- genpass16='openssl rand -base64 16'
alias -- genpass32='openssl rand -base64 32'
alias -- genpasshex='openssl rand -hex'
alias -- get='curl -X GET'
alias -- gf='git fetch --all --prune'
alias -- ggc='gh gist create'
alias -- ggist='gh gist'
alias -- ggl='gh gist list'
alias -- ggv='gh gist view'
alias -- gis='gh issue'
alias -- gisc='gh issue create'
alias -- giscl='gh issue close'
alias -- gise='gh issue edit'
alias -- gisl='gh issue list'
alias -- gisv='gh issue view'
alias -- gisvo='gh issue view --web'
alias -- gl='git log --oneline --graph --decorate'
alias -- gnb='git checkout -b'
alias -- gob='go build'
alias -- goba='go build ./...'
alias -- gobr='go build -race'
alias -- goclean='go clean'
alias -- gocleanc='go clean -cache'
alias -- gocleani='go clean -i'
alias -- godoc='go doc'
alias -- gof='go fmt'
alias -- gofa='go fmt ./...'
alias -- gog='go get'
alias -- gogu='go get -u'
alias -- goi='go install'
alias -- gom='go mod'
alias -- gomd='go mod download'
alias -- gomg='go mod graph'
alias -- gomi='go mod init'
alias -- gomt='go mod tidy'
alias -- gomv='go mod verify'
alias -- gor='go run'
alias -- gorr='go run -race'
alias -- got='go test'
alias -- gota='go test ./...'
alias -- gotb='go test -bench=.'
alias -- gotc='go test -cover'
alias -- gotr='go test -race'
alias -- gotv='go test -v'
alias -- govet='go vet'
alias -- goveta='go vet ./...'
alias -- gow='go work'
alias -- gowi='go work init'
alias -- gowu='go work use'
alias -- gp='git pull --ff-only'
alias -- gpgclearsign='gpg --clearsign'
alias -- gpgdec='gpg --decrypt'
alias -- gpgdel='gpg --delete-key'
alias -- gpgdelsec='gpg --delete-secret-key'
alias -- gpgenc='gpg --encrypt --armor'
alias -- gpgexp='gpg --export'
alias -- gpgexpsec='gpg --export-secret-keys'
alias -- gpggen='gpg --full-generate-key'
alias -- gpgimp='gpg --import'
alias -- gpglist='gpg --list-keys'
alias -- gpglistsec='gpg --list-secret-keys'
alias -- gpgsign='gpg --sign'
alias -- gpgver='gpg --verify'
alias -- gpr='gh pr'
alias -- gprc='gh pr create'
alias -- gprck='gh pr checkout'
alias -- gprl='gh pr list'
alias -- gprm='gh pr merge'
alias -- gprr='gh pr review'
alias -- gprs='gh pr status'
alias -- gprv='gh pr view'
alias -- gprvo='gh pr view --web'
alias -- gr=grep
alias -- grE='grep -E'
alias -- grc='gh repo clone'
alias -- grcr='gh repo create'
alias -- grec='gh release create'
alias -- grel='gh release'
alias -- grelist='gh release list'
alias -- grepc='grep -c'
alias -- grepo='gh repo'
alias -- grepv='grep -v'
alias -- grev='gh release view'
alias -- grf='gh repo fork'
alias -- gri='grep -i'
alias -- grl='grep -l'
alias -- grlist='gh repo list'
alias -- grn='grep -n'
alias -- grr='grep -r'
alias -- grun='gh run list'
alias -- grunv='gh run view'
alias -- grunw='gh run watch'
alias -- grv='gh repo view'
alias -- grvo='gh repo view --web'
alias -- gs='git status -sb'
alias -- gsa='git stash apply'
alias -- gsf='git status --short --branch'
alias -- gsl='git stash list'
alias -- gsp='git stash pop'
alias -- gss='git stash save'
alias -- gun='git reset HEAD~1'
alias -- gwl='gh workflow list'
alias -- gwr='gh workflow run'
alias -- gwtp='git worktree prune'
alias -- gwv='gh workflow view'
alias -- h=helm
alias -- h10='head -n 10'
alias -- h20='head -n 20'
alias -- hhist='helm history'
alias -- hl='helm list'
alias -- hla='helm list --all-namespaces'
alias -- hld='helm delete'
alias -- hli='helm install'
alias -- hlr='helm rollback'
alias -- hls='helm search repo'
alias -- hlt='helm lint'
alias -- hlu='helm upgrade'
alias -- hr='helm repo'
alias -- hra='helm repo add'
alias -- hrup='helm repo update'
alias -- ht=htop
alias -- htcpu='htop --sort-key PERCENT_CPU'
alias -- htmem='htop --sort-key PERCENT_MEM'
alias -- htpl='helm template'
alias -- http='http --pretty=all'
alias -- httpf='http --form'
alias -- httpfollow='http --follow'
alias -- httpj='http --json'
alias -- https='https --pretty=all'
alias -- httpv='http -v'
alias -- htu='htop -u $(whoami)'
alias -- htv='helm template --values'
alias -- ifaces='ip -br addr'
alias -- ifdown='sudo ip link set'
alias -- ifup='sudo ip link set'
alias -- ipy=ipython
alias -- jb='journalctl -b'
alias -- jctl=journalctl
alias -- je='journalctl -p err'
alias -- jf='journalctl -f'
alias -- jfu='journalctl -fu'
alias -- jk=jenkins-cli
alias -- jkb='jenkins-cli build'
alias -- jkbh='jenkins-cli build-history'
alias -- jkbs='jenkins-cli build-status'
alias -- jkc='jenkins-cli console'
alias -- jkcp='jenkins-cli copy-job'
alias -- jkcr='jenkins-cli create-job'
alias -- jkcred='jenkins-cli list-credentials'
alias -- jkdel='jenkins-cli delete-job'
alias -- jkget='jenkins-cli get-job'
alias -- jkgroovy='jenkins-cli groovy'
alias -- jkgsh='jenkins-cli groovysh'
alias -- jkh='jenkins-cli help'
alias -- jkl='jenkins-cli list-jobs'
alias -- jkn='jenkins-cli list-nodes'
alias -- jkncr='jenkins-cli create-node'
alias -- jknd='jenkins-cli delete-node'
alias -- jknoff='jenkins-cli offline-node'
alias -- jknon='jenkins-cli online-node'
alias -- jkp='jenkins-cli list-plugins'
alias -- jkpi='jenkins-cli install-plugin'
alias -- jkpr='jenkins-cli restart'
alias -- jkps='jenkins-cli safe-restart'
alias -- jkq='jenkins-cli list-queue'
alias -- jkqc='jenkins-cli cancel-queue'
alias -- jkstop='jenkins-cli stop-build'
alias -- jkv='jenkins-cli version'
alias -- jkwho='jenkins-cli who-am-i'
alias -- jlab='jupyter lab'
alias -- jnb='jupyter notebook'
alias -- jqc='jq -c'
alias -- jqkeys='jq "keys"'
alias -- jqr='jq -r'
alias -- jqs='jq -S'
alias -- jqvalues='jq "values"'
alias -- jsonformat='jq .'
alias -- jwtdecode='jq -R "split(\".\") | .[1] | @base64d | fromjson"'
alias -- k=kubectl
alias -- ka='kubectl apply -f'
alias -- kapplycb='kubectl apply -f - <<< "$(wl-paste 2>/dev/null || xclip -o)"'
alias -- kctx='kubectl config use-context'
alias -- kctxs='kubectl config get-contexts'
alias -- kd='kubectl describe'
alias -- kdel='kubectl delete -f'
alias -- kdp='kubectl describe pod'
alias -- kds='kubectl describe svc'
alias -- ke='kubectl edit'
alias -- kernelv='uname -r'
alias -- kex='kubectl exec -it'
alias -- kg='kubectl get'
alias -- kge='kubectl get events --sort-by=.metadata.creationTimestamp'
alias -- kgi='kubectl get ingress'
alias -- kgn='kubectl get nodes'
alias -- kgp='kubectl get pods'
alias -- kgs='kubectl get svc'
alias -- kl='kubectl logs'
alias -- klf='kubectl logs -f'
alias -- kns='kubectl config set-context --current --namespace'
alias -- knss='kubectl get ns'
alias -- krr='kubectl rollout restart'
alias -- krs='kubectl rollout status'
alias -- kru='kubectl rollout undo'
alias -- lastlogin=lastlog
alias -- limits='ulimit -a'
alias -- listening='ss -tuln'
alias -- loadavg='cat /proc/loadavg'
alias -- localip='ip addr show | grep '\''inet '\'' | grep -v 127.0.0.1 | awk '\''{print $2}'\'' | cut -d/ -f1'
alias -- ls=lsd
alias -- lsblk='lsblk -f'
alias -- lsmod='lsmod | sort'
alias -- lspci='lspci -v'
alias -- lspcitree='lspci -tv'
alias -- lsusb='lsusb -v'
alias -- lsusbtree='lsusb -t'
alias -- m=make
alias -- maxfiles='ulimit -n'
alias -- maxproc='ulimit -u'
alias -- mb='make build'
alias -- mc='make clean'
alias -- md='make dev'
alias -- memfree='free -h | grep Mem | awk "{print \$4}"'
alias -- meminfo='free -h'
alias -- memtotal='free -h | grep Mem | awk "{print \$2}"'
alias -- memused='free -h | grep Mem | awk "{print \$3}"'
alias -- mes=meson
alias -- mescomp='meson compile'
alias -- mesinst='meson install'
alias -- messetup='meson setup'
alias -- mestest='meson test'
alias -- mf='make -f'
alias -- mgo=mongosh
alias -- mgostart='sudo systemctl start mongod'
alias -- mgostatus='systemctl status mongod'
alias -- mgostop='sudo systemctl stop mongod'
alias -- mh='make help'
alias -- mi='make install'
alias -- mj='make -j'
alias -- mj4='make -j4'
alias -- mj8='make -j8'
alias -- mk='make -k'
alias -- mn='make -n'
alias -- modinfo=modinfo
alias -- mp='make prod'
alias -- mr='make run'
alias -- ms='make -s'
alias -- mt='make test'
alias -- my=mysql
alias -- mydump=mysqldump
alias -- myip='curl -s ifconfig.me'
alias -- myip4='curl -s -4 ifconfig.me'
alias -- myip6='curl -s -6 ifconfig.me'
alias -- mylist='mysql -e "SHOW DATABASES;"'
alias -- mylocalhost='mysql -h localhost -u root -p'
alias -- myrestart='sudo systemctl restart mysql'
alias -- mystart='sudo systemctl start mysql'
alias -- mystatus='systemctl status mysql'
alias -- mystop='sudo systemctl stop mysql'
alias -- n=npm
alias -- nb='npm run build'
alias -- nc='ninja -C build clean'
alias -- ncc='npm cache clean --force'
alias -- nd='npm run dev'
alias -- netstat-summary='ss -s'
alias -- netstats='watch -n 1 "ss -s"'
alias -- ni='npm install'
alias -- nid='npm install --save-dev'
alias -- nig='npm install -g'
alias -- ninit='npm init -y'
alias -- nj=ninja
alias -- njb='ninja -C build'
alias -- nl='npm list'
alias -- nls='npm list --depth=0'
alias -- no='npm outdated'
alias -- npub='npm publish'
alias -- nr='npm run'
alias -- nrb='npm run build'
alias -- nrd='npm run dev'
alias -- nrf='npm run format'
alias -- nrl='npm run lint'
alias -- nrt='npm run test'
alias -- ns='npm start'
alias -- nt='npm test'
alias -- nu='npm uninstall'
alias -- nug='npm uninstall -g'
alias -- nup='npm update'
alias -- nvmcur='nvm current'
alias -- nvmd='nvm use default'
alias -- nvmi='nvm install'
alias -- nvml='nvm list'
alias -- nvmu='nvm use'
alias -- osinfo='cat /etc/os-release'
alias -- p=ping
alias -- p4='ping -c 4'
alias -- p8='ping 8.8.8.8'
alias -- pg=psql
alias -- pgdump=pg_dump
alias -- pglist='psql -l'
alias -- pglocalhost='psql -h localhost -U postgres'
alias -- pgrestart='sudo systemctl restart postgresql'
alias -- pgrestore=pg_restore
alias -- pgstart='sudo systemctl start postgresql'
alias -- pgstatus='systemctl status postgresql'
alias -- pgstop='sudo systemctl stop postgresql'
alias -- pipf='pip freeze'
alias -- pipfr='pip freeze > requirements.txt'
alias -- pipi='pip install'
alias -- pipl='pip list'
alias -- pipr='pip install -r requirements.txt'
alias -- pipu='pip install --upgrade'
alias -- pipun='pip uninstall'
alias -- po=poetry
alias -- poa='poetry add'
alias -- poad='poetry add --group dev'
alias -- pob='poetry build'
alias -- poi='poetry install'
alias -- pop='poetry publish'
alias -- por='poetry remove'
alias -- ports='netstat -tulanp'
alias -- poru='poetry run'
alias -- poshow='poetry show'
alias -- post='curl -X POST'
alias -- pou='poetry update'
alias -- prettyjson='python3 -m json.tool'
alias -- psa='ps aux'
alias -- psg='ps aux | grep'
alias -- pstree='pstree -p'
alias -- put='curl -X PUT'
alias -- py=python
alias -- py3=python3
alias -- pyt=pytest
alias -- pytc='pytest --cov'
alias -- pytest='pytest -v'
alias -- red=redis-cli
alias -- redstart='sudo systemctl start redis'
alias -- redstatus='systemctl status redis'
alias -- redstop='sudo systemctl stop redis'
alias -- rg='rg --smart-case'
alias -- rgc='rg -c'
alias -- rgi='rg -i'
alias -- rgl='rg -l'
alias -- rgt='rg --type'
alias -- rgv='rg --invert-match'
alias -- route4='ip -4 route'
alias -- route6='ip -6 route'
alias -- routes='ip route'
alias -- run-help=man
alias -- sactive='systemctl list-units --state=active'
alias -- sctl=systemctl
alias -- sctlu='systemctl --user'
alias -- sdaemon='sudo systemctl daemon-reload'
alias -- sdisable='sudo systemctl disable'
alias -- sedd='sed -n'
alias -- sedi='sed -i'
alias -- sedr='sed -r'
alias -- senable='sudo systemctl enable'
alias -- sfailed='systemctl list-units --state=failed'
alias -- shred='shred -vfz -n 10'
alias -- slist='systemctl list-units --type=service'
alias -- slistall='systemctl list-units --type=service --all'
alias -- sortk='sort -k'
alias -- sortn='sort -n'
alias -- sortr='sort -r'
alias -- sortu='sort -u'
alias -- speedtest=speedtest-cli
alias -- speedtest-simple='speedtest-cli --simple'
alias -- spoweroff='sudo systemctl poweroff'
alias -- sreboot='sudo systemctl reboot'
alias -- sreload='sudo systemctl reload'
alias -- srestart='sudo systemctl restart'
alias -- sshadd=ssh-add
alias -- sshaddlist='ssh-add -l'
alias -- sshagent='eval "$(ssh-agent -s)"'
alias -- sshcopy=ssh-copy-id
alias -- sshkey='ssh-keygen -t ed25519 -C'
alias -- sshkeyrsa='ssh-keygen -t rsa -b 4096 -C'
alias -- sshlist='ls -la ~/.ssh'
alias -- sshperms='chmod 700 ~/.ssh && chmod 600 ~/.ssh/*'
alias -- sshtest='ssh -T'
alias -- sslcheck='openssl x509 -in'
alias -- sslcheckdates='openssl x509 -dates -noout -in'
alias -- sslcheckmod='openssl x509 -modulus -noout -in'
alias -- sslchecktext='openssl x509 -text -noout -in'
alias -- sslgen='openssl req -new -x509 -days 365 -nodes'
alias -- sslgencsr='openssl req -new -key'
alias -- sslgenkey='openssl genrsa -out'
alias -- ssltest='openssl s_client -connect'
alias -- ssltesthttp='openssl s_client -connect -servername'
alias -- sslverify='openssl verify'
alias -- sstart='sudo systemctl start'
alias -- sstatus='systemctl status'
alias -- sstop='sudo systemctl stop'
alias -- swapinfo='free -h | grep Swap'
alias -- sysinfo='uname -a'
alias -- t=tail
alias -- t10='tail -n 10'
alias -- t20='tail -n 20'
alias -- tailf='tail -f'
alias -- tcpdump-dns='sudo tcpdump -i any -s 0 port 53'
alias -- tcpdump-http='sudo tcpdump -i any -A -s 0 "tcp port 80 or tcp port 443"'
alias -- temp='sensors 2>/dev/null || cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null'
alias -- tf=terraform
alias -- tfa='terraform apply'
alias -- tfaa='terraform apply tfplan'
alias -- tfd='terraform destroy'
alias -- tff='terraform fmt'
alias -- tfi='terraform init'
alias -- tfo='terraform output'
alias -- tfp='terraform plan'
alias -- tfpa='terraform plan -out=tfplan'
alias -- tfs='terraform show'
alias -- tfsl='terraform state list'
alias -- tfsrm='terraform state rm'
alias -- tfss='terraform state show'
alias -- tfv='terraform validate'
alias -- tfw='terraform workspace'
alias -- tfwl='terraform workspace list'
alias -- tfwn='terraform workspace new'
alias -- tfws='terraform workspace select'
alias -- tm=tmux
alias -- tma='tmux attach'
alias -- tmat='tmux attach -t'
alias -- tmk='tmux kill-session -t'
alias -- tmka='tmux kill-server'
alias -- tml='tmux list-sessions'
alias -- tmn='tmux new'
alias -- tmns='tmux new -s'
alias -- tmp='tmux list-panes'
alias -- tms=tmux_smart_attach
alias -- tmw='tmux list-windows'
alias -- topcpu='ps aux --sort=-%cpu | head -11'
alias -- topmem='ps aux --sort=-%mem | head -11'
alias -- trl='tr "[:upper:]" "[:lower:]"'
alias -- tru='tr "[:lower:]" "[:upper:]"'
alias -- tt=taskwarrior-tui
alias -- udaemon='systemctl --user daemon-reload'
alias -- udisable='systemctl --user disable'
alias -- uenable='systemctl --user enable'
alias -- uniqc='uniq -c'
alias -- uniqd='uniq -d'
alias -- uniqi='uniq -i'
alias -- uptime='uptime -p'
alias -- urestart='systemctl --user restart'
alias -- urldecode='python3 -c "import sys, urllib.parse as ul; print(ul.unquote_plus(sys.argv[1]))"'
alias -- urlencode='python3 -c "import sys, urllib.parse as ul; print(ul.quote_plus(sys.argv[1]))"'
alias -- userlist='cut -d: -f1 /etc/passwd | sort'
alias -- users=who
alias -- ustart='systemctl --user start'
alias -- ustatus='systemctl --user status'
alias -- ustop='systemctl --user stop'
alias -- uv=uv
alias -- uva='uv add'
alias -- uvad='uv add --dev'
alias -- uvi='uv init'
alias -- uvl='uv lock'
alias -- uvpc='uv pip compile'
alias -- uvpf='uv pip freeze'
alias -- uvpi='uv pip install'
alias -- uvpl='uv pip list'
alias -- uvps='uv pip sync'
alias -- uvpu='uv pip uninstall'
alias -- uvpy='uv python'
alias -- uvpyi='uv python install'
alias -- uvpyl='uv python list'
alias -- uvr='uv remove'
alias -- uvrun='uv run'
alias -- uvs='uv sync'
alias -- uvt='uv tree'
alias -- uvvenv='uv venv'
alias -- v=vault
alias -- va='vault auth'
alias -- vact='source venv/bin/activate'
alias -- vad='vault auth disable'
alias -- vae='vault auth enable'
alias -- val='vault auth list'
alias -- vd='vault delete'
alias -- vdeact=deactivate
alias -- venv='python -m venv venv'
alias -- verify='sha256sum -c'
alias -- vg=vagrant
alias -- vgb='vagrant box'
alias -- vgba='vagrant box add'
alias -- vgbl='vagrant box list'
alias -- vgbr='vagrant box remove'
alias -- vgbu='vagrant box update'
alias -- vgd='vagrant destroy'
alias -- vgdf='vagrant destroy -f'
alias -- vgh='vagrant halt'
alias -- vgp='vagrant provision'
alias -- vgpi='vagrant plugin install'
alias -- vgpl='vagrant plugin list'
alias -- vgport='vagrant port'
alias -- vgpu='vagrant plugin uninstall'
alias -- vgpup='vagrant plugin update'
alias -- vgr='vagrant reload'
alias -- vgres='vagrant resume'
alias -- vgs='vagrant ssh'
alias -- vgsnap='vagrant snapshot'
alias -- vgssh='vagrant ssh-config'
alias -- vgst='vagrant status'
alias -- vgsus='vagrant suspend'
alias -- vgu='vagrant up'
alias -- vi=nvim
alias -- vim=nvim
alias -- vkv='vault kv'
alias -- vkvdel='vault kv delete'
alias -- vkvget='vault kv get'
alias -- vkvlist='vault kv list'
alias -- vkvmeta='vault kv metadata'
alias -- vkvput='vault kv put'
alias -- vl='vault login'
alias -- vle='vault lease'
alias -- vlel='vault lease lookup'
alias -- vler='vault lease revoke'
alias -- vls='vault list'
alias -- vop='vault operator'
alias -- vopi='vault operator init'
alias -- vopr='vault operator rekey'
alias -- vops='vault operator seal'
alias -- vopu='vault operator unseal'
alias -- vp='vault policy'
alias -- vpd='vault policy delete'
alias -- vpl='vault policy list'
alias -- vpr='vault policy read'
alias -- vpw='vault policy write'
alias -- vr='vault read'
alias -- vs='vault status'
alias -- vse='vault secrets'
alias -- vsed='vault secrets disable'
alias -- vsee='vault secrets enable'
alias -- vsel='vault secrets list'
alias -- vsem='vault secrets move'
alias -- vset='vault secrets tune'
alias -- vt='vault token'
alias -- vtc='vault token create'
alias -- vtl='vault token lookup'
alias -- vtr='vault token revoke'
alias -- vtre='vault token renew'
alias -- vw='vault write'
alias -- wcc='wc -c'
alias -- wcl='wc -l'
alias -- wcw='wc -w'
alias -- wget-continue='wget -c'
alias -- wget-mirror='wget --mirror --convert-links --adjust-extension --page-requisites --no-parent'
alias -- wget-page='wget --page-requisites --convert-links'
alias -- wgetjson='wget --header="Content-Type: application/json"'
alias -- wgetpost='wget --post-data'
alias -- which-command=whence
alias -- wipe='wipe -r'
alias -- y=yarn
alias -- ya='yarn add'
alias -- yad='yarn add --dev'
alias -- yag='yarn global add'
alias -- yb='yarn build'
alias -- yd='yarn dev'
alias -- yout='yarn outdated'
alias -- yqr='yq -r'
alias -- yqy='yq -o=yaml'
alias -- yr='yarn remove'
alias -- ys='yarn start'
alias -- yt='yarn test'
alias -- yup='yarn upgrade'
alias -- z=__zoxide_z
alias -- zi=__zoxide_zi
# Check for rg availability
if ! (unalias rg 2>/dev/null; command -v rg) >/dev/null 2>&1; then
  function rg {
  local _cc_bin="${CLAUDE_CODE_EXECPATH:-}"
  [[ -x $_cc_bin ]] || _cc_bin=/home/udai/.local/bin/claude
  if [[ ! -x $_cc_bin ]]; then command rg ${1+"$@"}; return; fi
  if [[ -n ${ZSH_VERSION:-} ]]; then
    ARGV0=rg "$_cc_bin" ${1+"$@"}
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    ARGV0=rg "$_cc_bin" ${1+"$@"}
  else
    (exec -a rg "$_cc_bin" ${1+"$@"})
  fi
}
fi
# Shadow find/grep with embedded bfs/ugrep
unalias find 2>/dev/null || true
unalias grep 2>/dev/null || true
function find {
  local _cc_bin="${CLAUDE_CODE_EXECPATH:-}"
  [[ -x $_cc_bin ]] || _cc_bin=/home/udai/.local/bin/claude
  if [[ ! -x $_cc_bin ]]; then command find ${1+"$@"}; return; fi
  if [[ -n ${ZSH_VERSION:-} ]]; then
    ARGV0=bfs "$_cc_bin" -S dfs -regextype findutils-default ${1+"$@"}
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    ARGV0=bfs "$_cc_bin" -S dfs -regextype findutils-default ${1+"$@"}
  else
    (exec -a bfs "$_cc_bin" -S dfs -regextype findutils-default ${1+"$@"})
  fi
}
function grep {
  local _cc_a
  for _cc_a in ${1+"$@"}; do
    case "$_cc_a" in -*-filter*|-*-pager*|-*-view*|-*-format-open*|-*-config*|---*|-@*|-*-save-config*|-[Zz]*|-[!-]*[Zz]*|--null|--null-data) command grep ${1+"$@"}; return ;; esac
  done
  local _cc_bin="${CLAUDE_CODE_EXECPATH:-}"
  [[ -x $_cc_bin ]] || _cc_bin=/home/udai/.local/bin/claude
  if [[ ! -x $_cc_bin ]]; then command grep ${1+"$@"}; return; fi
  if [[ -n ${ZSH_VERSION:-} ]]; then
    ARGV0=ugrep "$_cc_bin" -G --ignore-files --hidden -I --exclude-dir=.git --exclude-dir=.svn --exclude-dir=.hg --exclude-dir=.bzr --exclude-dir=.jj --exclude-dir=.sl ${1+"$@"}
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    ARGV0=ugrep "$_cc_bin" -G --ignore-files --hidden -I --exclude-dir=.git --exclude-dir=.svn --exclude-dir=.hg --exclude-dir=.bzr --exclude-dir=.jj --exclude-dir=.sl ${1+"$@"}
  else
    (exec -a ugrep "$_cc_bin" -G --ignore-files --hidden -I --exclude-dir=.git --exclude-dir=.svn --exclude-dir=.hg --exclude-dir=.bzr --exclude-dir=.jj --exclude-dir=.sl ${1+"$@"})
  fi
}
# Shadow pkill to refuse patterns matching the CLI process
unalias pkill 2>/dev/null || true
function pkill {
  if [ -n "${CLAUDE_PID:-}" ] && [ -r "/proc/${CLAUDE_PID}/comm" ]; then
    local _cc_skip="" _cc_a
    local -a _cc_probe=()
    for _cc_a in ${1+"$@"}; do
      if [ -n "$_cc_skip" ]; then _cc_skip=""; continue; fi
      case "$_cc_a" in
        --signal) _cc_skip=1 ;;
        --signal=*|-e|--echo) ;;
        -[0-9]*) ;;
        -[PUGOF]?*) _cc_probe+=("$_cc_a") ;;
        -[ABCDEFGHIJKLMNOPQRSTUVWXYZ][ABCDEFGHIJKLMNOPQRSTUVWXYZ0-9]*) ;;
        *) _cc_probe+=("$_cc_a") ;;
      esac
    done
    if command pgrep ${_cc_probe[@]+"${_cc_probe[@]}"} 2>/dev/null | command grep -qx "${CLAUDE_PID}"; then
      printf 'pkill: refusing to run — this pattern matches the Claude CLI process (PID %s). Narrow the pattern, or target your own children with `pkill -P $$ ...`.\n' "${CLAUDE_PID}" >&2
      return 1
    fi
  fi
  command pkill ${1+"$@"}
}
export PATH=/home/udai/.bun/bin:/home/udai/.opencode/bin:/home/udai/.dotfiles/bin:/home/udai/.cargo/bin:/home/udai/go/bin:/home/udai/.local/bin:/home/udai/.sware/bin:/home/udai/anaconda3/bin:/home/udai/anaconda3/condabin:/home/udai/.bun/bin:/home/udai/.opencode/bin:/home/udai/.nvm/versions/node/v24.18.0/bin:/home/udai/.dotfiles/bin:/home/udai/.cargo/bin:/home/udai/go/bin:/home/udai/.local/bin:/home/udai/.sware/bin:/home/udai/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/local/go/bin:/home/udai/personal/aegis/.claude/plugins/cache/claude-plugins-official/pyright-lsp/1.0.0/bin:/home/udai/personal/aegis/.claude/plugins/cache/claude-plugins-official/typescript-lsp/1.0.0/bin:/home/udai/personal/aegis/.claude/plugins/cache/claude-plugins-official/gopls-lsp/1.0.0/bin:/home/udai/personal/aegis/.claude/plugins/cache/claude-plugins-official/rust-analyzer-lsp/1.0.0/bin:/home/udai/personal/aegis/.claude/plugins/cache/claude-plugins-official/clangd-lsp/1.0.0/bin:/home/udai/personal/aegis/.claude/plugins/cache/claude-plugins-official/jdtls-lsp/1.0.0/bin
