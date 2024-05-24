#!/bin/sh

RC='\e[0m'
RED='\e[31m'
YELLOW='\e[33m'
GREEN='\e[32m'

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

## Function to grant sudo permissions to the current user
grant_sudo_permissions() {
    # Prompt for the root password
    su -c "usermod -aG sudo ${USER}"
    echo "Sudo permissions granted to user ${USER}"
}

# Check if the user is in the sudo group
if id -nG "${USER}" | grep -qw "sudo"; then
    echo "User ${USER} is already in the sudo group"
else
    grant_sudo_permissions
fi

checkEnv() {
    ## Check for requirements.
    REQUIREMENTS='curl groups sudo'
    for req in ${REQUIREMENTS}; do
        if ! command_exists "$req"; then
            echo -e "${RED}To run me, you need: ${req}${RC}"
            exit 1
        fi
    done

    ## Check Package Manager
    PACKAGEMANAGER='nala apt yum dnf pacman zypper'
    for pgm in ${PACKAGEMANAGER}; do
        if command_exists "$pgm"; then
            PACKAGER="$pgm"
            echo -e "Using ${pgm}"
            break
        fi
    done

    if [ -z "${PACKAGER}" ]; then
        echo -e "${RED}Can't find a supported package manager${RC}"
        exit 1
    fi

    ## Check if the current directory is writable.
    GITPATH="$(dirname "$(realpath "$0")")"
    if [ ! -w "${GITPATH}" ]; then
        echo -e "${RED}Can't write to ${GITPATH}${RC}"
        exit 1
    fi

    ## Check SuperUser Group
    SUPERUSERGROUP='wheel sudo root'
    for sug in ${SUPERUSERGROUP}; do
        if groups | grep -q "$sug"; then
            SUGROUP="$sug"
            echo -e "Super user group ${SUGROUP}"
            break
        fi
    done

    ## Check if member of the sudo group.
    if ! groups | grep -q "$SUGROUP"; then
        echo -e "${RED}You need to be a member of the sudo group to run me!${RC}"
        exit 1
    fi
}

installDepend() {
    ## Check for dependencies.
    DEPENDENCIES='bash bash-completion tar neovim bat tree multitail'
    echo -e "${YELLOW}Installing dependencies...${RC}"
    if [ "$PACKAGER" = "nala" ] || [ "$PACKAGER" = "apt" ]; then
        for pkg in $DEPENDENCIES; do
            read -p "Would you like to install $pkg package? [Y/n]: " choice
            case "$choice" in
                y|Y|'') sudo "$PACKAGER" install -y "$pkg" ;;
                n|N) ;;
                *) echo "Invalid choice. Defaulting to yes." && sudo "$PACKAGER" install -y "$pkg" ;;
            esac
        done
    elif [ "$PACKAGER" = "yum" ] || [ "$PACKAGER" = "dnf" ]; then
        for pkg in $DEPENDENCIES; do
            read -p "Would you like to install $pkg package? [Y/n]: " choice
            case "$choice" in
                y|Y|'') sudo "$PACKAGER" install -y "$pkg" ;;
                n|N) ;;
                *) echo "Invalid choice. Defaulting to yes." && sudo "$PACKAGER" install -y "$pkg" ;;
            esac
        done
    elif [ "$PACKAGER" = "pacman" ]; then
        for pkg in $DEPENDENCIES; do
            read -p "Would you like to install $pkg package? [Y/n]: " choice
            case "$choice" in
                y|Y|'') sudo "$PACKAGER" -S --noconfirm "$pkg" ;;
                n|N) ;;
                *) echo "Invalid choice. Defaulting to yes." && sudo "$PACKAGER" -S --noconfirm "$pkg" ;;
            esac
        done
    elif [ "$PACKAGER" = "zypper" ]; then
        for pkg in $DEPENDENCIES; do
            read -p "Would you like to install $pkg package? [Y/n]: " choice
            case "$choice" in
                y|Y|'') sudo "$PACKAGER" install -y "$pkg" ;;
                n|N) ;;
                *) echo "Invalid choice. Defaulting to yes." && sudo "$PACKAGER" install -y "$pkg" ;;
            esac
        done
    else
        echo "Unsupported package manager: $PACKAGER"
    fi
}

installOhMyPosh() {
    if command_exists oh-my-posh; then
        echo "Oh-My-Posh already installed"
        return
    fi

    if ! curl -sS https://ohmyposh.dev/install.sh | bash -s; then
        echo -e "${RED}Something went wrong during oh-my-posh install!${RC}"
        exit 1
    fi

    oh-my-posh font install

    if command_exists fzf; then
        echo "Fzf already installed"
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install
    fi
}

installZoxide() {
    if command_exists zoxide; then
        echo "Zoxide already installed"
        return
    fi

    if ! curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
        echo -e "${RED}Something went wrong during zoxide install!${RC}"
        exit 1
    fi
}

installFastfetch() {
    if command_exists fastfetch; then
        echo "fastfetch already installed"
        return
    fi

    echo -e "${YELLOW}Installing fastfetch...${RC}"
    if [ "$PACKAGER" = "nala" ] || [ "$PACKAGER" = "apt" ]; then
        if ! curl -sSL https://github.com/fastfetch-cli/fastfetch/releases/download/2.13.2/fastfetch-linux-amd64.deb -o fastfetch-linux-amd64.deb || ! sudo dpkg -i fastfetch-linux-amd64.deb; then
            echo -e "${RED}Something went wrong during fastfetch install${RC}"
            exit 1
        fi
    else
        sudo "$PACKAGER" install -y fastfetch
    fi
}

installCleanup() {
    echo -e "${GREEN}Cleanup not implemented yet.${RC}"
}

install_additional_dependencies() {
    sudo apt update
    sudo apt install -y trash-cli bat meld jpico
}

linkConfig() {
    ## Get the correct user home directory.
    USER_HOME=$(getent passwd "${SUDO_USER:-${USER}}" | cut -d: -f6)
    ## Check if a bashrc file is already there.
    OLD_BASHRC="${USER_HOME}/.bashrc"
    if [ -e "${OLD_BASHRC}" ]; then
        echo -e "${YELLOW}Moving old bash config file to ${USER_HOME}/.bashrc.bak${RC}"
        if ! mv "${OLD_BASHRC}" "${USER_HOME}/.bashrc.bak"; then
            echo -e "${RED}Can't move the old bash config file!${RC}"
            exit 1
        fi
    fi

    echo -e "${YELLOW}Linking new bash config file...${RC}"
    ## Make symbolic link.
    ln -svf "${GITPATH}/.bashrc" "${USER_HOME}/.bashrc"
}

checkEnv
installDepend
installOhMyPosh
installZoxide
installFastfetch
install_additional_dependencies
installCleanup

if linkConfig; then
    echo -e "${GREEN}Done!\nRestart your shell to see the changes.${RC}"
else
    echo -e "${RED}Something went wrong!${RC}"
fi
