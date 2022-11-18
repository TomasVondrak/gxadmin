error() {
	(>&2 echo "$(tput setab 1)$*$(tput sgr0)")
}

warning() {
	(>&2 echo "$(tput setab 2)$*$(tput sgr0)")
}

success() {
	echo "$(tput setaf 40)$*$(tput sgr0)"
}

debug() {
	if (( GXADMIN_DEBUG == 1 )); then
		(>&2 echo "$(tput setab 2)[DEBUG] $*$(tput sgr0)")
	fi
}
