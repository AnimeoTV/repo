#!/bin/sh
set -e
# Script d'installation d'Animeo TV, créé à partir des scripts d'installation de Docker (https://get.docker.com) et du repo NodeSource (https://deb.nodesource.com/setup_18.x)

print_status() {
    echo
    echo "## $1"
    echo
}

if test -t 1; then # if terminal
    ncolors=$(which tput > /dev/null && tput colors) # supports color
    if test -n "$ncolors" && test $ncolors -ge 8; then
        termcols=$(tput cols)
        bold="$(tput bold)"
        underline="$(tput smul)"
        standout="$(tput smso)"
        normal="$(tput sgr0)"
        black="$(tput setaf 0)"
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
        yellow="$(tput setaf 3)"
        blue="$(tput setaf 4)"
        magenta="$(tput setaf 5)"
        cyan="$(tput setaf 6)"
        white="$(tput setaf 7)"
    fi
fi

print_bold() {
    title="$1"
    text="$2"

    echo
    echo "${red}================================================================================${normal}"
    echo "${red}================================================================================${normal}"
    echo
    echo "  ${bold}${yellow}${title}${normal}"
    echo
    echo "  ${text}"
    echo
    echo "${red}================================================================================${normal}"
    echo "${red}================================================================================${normal}"
}

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

is_darwin() {
	case "$(uname -s)" in
	*darwin* ) true ;;
	*Darwin* ) true ;;
	* ) false;;
	esac
}

deprecation_notice() {
	distro=$1
	distro_version=$2

	print_bold \
"                                   ERREUR                                   " "\
Cette distribution Linux ($distro $distro_version) a atteint la ${bold}fin de vie ${normal}et n'est plus supportée par ce script.
Veuillez utiliser une ${bold}version actuellement maintenue${normal} de $distro
ou installer l'application manuellement.
"
	exit 1
}

get_distribution() {
	lsb_dist=""
	# Every system that we officially support has /etc/os-release
	if [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	# Returning an empty string here should be alright since the
	# case statements don't act unless you provide an actual value
	echo "$lsb_dist"
}

# Check if this is a forked Linux distro
check_forked() {

	# Check for lsb_release command existence, it usually exists in forked distros
	if command_exists lsb_release; then
		# Check if the `-u` option is supported
		set +e
		lsb_release -a -u > /dev/null 2>&1
		lsb_release_exit_code=$?
		set -e

		# Check if the command has exited successfully, it means we're in a forked distro
		if [ "$lsb_release_exit_code" = "0" ]; then
			# Get the upstream release info
			lsb_dist=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'id' | cut -d ':' -f 2 | tr -d '[:space:]')
			dist_version=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'codename' | cut -d ':' -f 2 | tr -d '[:space:]')
		else
			if [ -r /etc/debian_version ] && [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "raspbian" ]; then
				if [ "$lsb_dist" = "osmc" ]; then
					# OSMC runs Raspbian
					lsb_dist=raspbian
				else
					# We're Debian and don't even know it!
					lsb_dist=debian
				fi
				dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
				case "$dist_version" in
					12)
						dist_version="bookworm"
					;;
					11)
						dist_version="bullseye"
					;;
					10)
						dist_version="buster"
					;;
					9)
						dist_version="stretch"
					;;
					8)
						dist_version="jessie"
					;;
				esac
			fi
		fi
	fi
}

do_install() {
	print_status "Script d'installation d'Animeo TV"

	if command_exists animeo-tv-desktop; then
	    print_bold \
"                               AVERTISSEMENT                                " "\
L'application Animeo TV à l'air d'être déjà installé sur votre système.
  Si vous voulez la désinstaller, la commande ${bold}\"sudo apt uninstall animeo-tv-desktop${normal}\"
  est probablement celle que vous cherchez.

  Vous pouvez appuyer sur CTRL+C pour arrêter le script, ou attendre 20 secondes pour que l'installation continue.
"
		sleep 20
	fi

	if [ "$(uname -m)" != "amd64" ] && [ "$(uname -m)" != "x86_64" ]; then
		print_status "Désolé, l'application Animeo TV n'est disponible que sur les processeurs ${bold}amd64/x86_64${normal}."
		exit 1
	fi

	user="$(id -un 2>/dev/null || true)"

	sh_c='sh -c'
	if [ "$user" != 'root' ]; then
		if command_exists sudo; then
			sh_c='sudo -E sh -c'
		elif command_exists su; then
			sh_c='su -c'
		else
		    print_bold \
"                                   ERREUR                                   " "\
L'installateur a besoin d'exécuter des commandes ${bold}en tant que root${normal}.
  Nous n'avons réussi à trouver ${bold}ni \"sudo\" ni \"su\"${normal} pour que cela ce produise.
"
			exit 1
		fi
	fi

	# perform some very rudimentary platform detection
	lsb_dist=$( get_distribution )
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	case "$lsb_dist" in

		ubuntu)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
				dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
			fi
		;;

		debian|raspbian)
			dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
			case "$dist_version" in
				12)
					dist_version="bookworm"
				;;
				11)
					dist_version="bullseye"
				;;
				10)
					dist_version="buster"
				;;
				9)
					dist_version="stretch"
				;;
				8)
					dist_version="jessie"
				;;
			esac
		;;

		centos|rhel)
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
		;;

		*)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --release | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
		;;

	esac

	# Check if this is a forked Linux distro
	check_forked

	# Print deprecation errors for distro versions that recently reached EOL,
	# but may still be commonly used (especially LTS versions).
	case "$lsb_dist.$dist_version" in
		debian.stretch|debian.jessie)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		raspbian.stretch|raspbian.jessie)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		ubuntu.xenial|ubuntu.trusty)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		ubuntu.impish|ubuntu.hirsute|ubuntu.groovy|ubuntu.eoan|ubuntu.disco|ubuntu.cosmic)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		fedora.*)
			if [ "$dist_version" -lt 36 ]; then
				deprecation_notice "$lsb_dist" "$dist_version"
			fi
			;;
	esac

	# Run setup for each distro accordingly
	case "$lsb_dist" in
		ubuntu|debian|raspbian)
			pre_reqs="apt-transport-https ca-certificates curl"
			if ! command -v gpg > /dev/null; then
				pre_reqs="$pre_reqs gnupg"
			fi
			apt_repo="deb [arch=amd64 signed-by=/etc/apt/keyrings/animeo.gpg] https://repo.animeovf.fr/repository/apt jammy main"
			(
				print_status "Actualisation des paquets..."
				$sh_c 'apt-get update'
				print_status "Installation des pré-requis..."
				$sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y $pre_reqs"
				print_status "Ajout de la clé GPG du repo Animeo TV..."
				$sh_c 'install -m 0755 -d /etc/apt/keyrings'
				$sh_c "curl -fsSL \"https://raw.githubusercontent.com/AnimeoTV/repo/master/repo_public.pgp\" | gpg --dearmor --yes -o /etc/apt/keyrings/animeo.gpg"
				$sh_c "chmod a+r /etc/apt/keyrings/animeo.gpg"
				print_status "Ajout du repo Animeo TV..."
				$sh_c "echo \"$apt_repo\" > /etc/apt/sources.list.d/animeo.list"
				print_status "Actualisation des paquets..."
				$sh_c 'apt-get update'
				print_status "Installation d'Animeo TV..."
				$sh_c "DEBIAN_FRONTEND=noninteractive apt-get install -y animeo-tv-desktop"
			)
			print_status "Animeo TV est désormais installé !"
			exit 0
			;;
		centos|fedora|rhel)
			if [ "$lsb_dist" = "fedora" ]; then
				pkg_manager="dnf"
				config_manager="dnf config-manager"
				enable_channel_flag="--set-enabled"
				disable_channel_flag="--set-disabled"
				pre_reqs="dnf-plugins-core"
				pkg_suffix="fc$dist_version"
			else
				pkg_manager="yum"
				config_manager="yum-config-manager"
				enable_channel_flag="--enable"
				disable_channel_flag="--disable"
				pre_reqs="yum-utils"
				pkg_suffix="el"
			fi
			repo_file_url="https://raw.githubusercontent.com/AnimeoTV/repo/master/animeo.repo"
			(
				print_status "Installation des pré-requis..."
				$sh_c "$pkg_manager install -y $pre_reqs"
				print_status "Ajout du repo Animeo TV..."
				$sh_c "$config_manager --add-repo $repo_file_url"
				$sh_c "$pkg_manager makecache"
				print_status "Installation d'Animeo TV..."
				$sh_c "$pkg_manager install -y animeo-tv-desktop"
			)
			print_status "Animeo TV est désormais installé !"
			exit 0
			;;
		*)
			if [ -z "$lsb_dist" ]; then
				if is_darwin; then
					print_status "macOS n'est pas supporté par ce script."
					print_status "Veuillez télécharger l'application ici : https://update.animeovf.fr/"
					exit 1
				fi
			fi
			print_status "La distribution '$lsb_dist' n'est pas supportée par ce script."
			exit 1
			;;
	esac
	exit 1
}

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"
do_install
