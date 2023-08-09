#!/bin/bash

# Set the desired GitHub repository
repo="go-gost/gost"
base_url="https://api.github.com/repos/$repo/releases"

# Retrieve available versions from GitHub API
versions=$(curl -s "$base_url" | grep -oP 'tag_name": "\K[^"]+')
latest_version=$(echo "$versions" | head -n 1)

# Check Root User
# If you want to run as another user, please modify $EUID to be owned by this user
if [[ "$EUID" -ne '0' ]]; then
    echo "$(tput setaf 1)Error: You must run this script as root!$(tput sgr0)"
    exit 1
fi

# Function to download and install gost
function check_file()
{
    if test ! -d "/usr/lib/systemd/system/";then
        `mkdir /usr/lib/systemd/system`
        `chmod -R 777 /usr/lib/systemd/system`
    fi
}
function check_nor_file()
{
    `rm -rf "$(pwd)"/gost`
    `rm -rf "$(pwd)"/gost.service`
    `rm -rf "$(pwd)"/gost.yaml`
    `rm -rf /etc/gost`
    `rm -rf /usr/lib/systemd/system/gost.service`
    `rm -rf /usr/bin/gost`
}
function install_gost() {
    check_nor_file
    check_file
    version=$1
    # Detect the operating system
    if [[ "$(uname)" == "Linux" ]]; then
        os="linux"
    elif [[ "$(uname)" == "Darwin" ]]; then
        os="darwin"
    elif [[ "$(uname)" == "MINGW"* ]]; then
        os="windows"
    else
        echo "Unsupported operating system."
        exit 1
    fi

    # Detect the CPU architecture
    arch=$(uname -m)
    case $arch in
    x86_64)
        cpu_arch="amd64"
        ;;
    armv5*)
        cpu_arch="armv5"
        ;;
    armv6*)
        cpu_arch="armv6"
        ;;
    armv7*)
        cpu_arch="armv7"
        ;;
    aarch64)
        cpu_arch="arm64"
        ;;
    i686)
        cpu_arch="386"
        ;;
    mips64*)
        cpu_arch="mips64"
        ;;
    mips*)
        cpu_arch="mips"
        ;;
    mipsel*)
        cpu_arch="mipsle"
        ;;
    *)
        echo "Unsupported CPU architecture."
        exit 1
        ;;
    esac
    get_download_url="$base_url/tags/$version"
    download_url=$(curl -s "$get_download_url" | grep -Eo "\"browser_download_url\": \".*${os}.*${cpu_arch}.*\"" | awk -F'["]' '{print $4}')

    # Download the binary
    echo "Downloading gost version $version..."
    curl -fsSL -o gost.tar.gz $download_url

    # Extract and install the binary
    echo "Installing gost..."
    tar -xzf gost.tar.gz
    chmod +x gost
    mv gost /usr/bin/gost
    chmod -R 777 /usr/bin/gost
    
cat >gost.service<<END
[Unit]
Description=gost
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=always
RestartSec=60
ExecReload=/bin/kill -SIGUSR1 $MAINPID
KillMode=process
ExecStart=/usr/bin/gost -C /etc/gost/gost.yaml

[Install]
WantedBy=multi-user.target    
END
cat >gost.yaml<<END
log:
   level: debug
END
    chmod -R 777 gost.service && mv gost.service /usr/lib/systemd/system
    mkdir /etc/gost && mv gost.yaml /etc/gost && chmod -R 777 /etc/gost
    systemctl enable gost && systemctl restart gost

  if test -a /usr/bin/gost -a /usr/lib/systemctl/gost.service -a /etc/gost/gost.yaml; then
    echo "gost install success"
    rm -rf "$(pwd)"/gost
    rm -rf "$(pwd)"/gost.service
    rm -rf "$(pwd)"/gost.yaml
  else
    echo "gost install failed"
    rm -rf "$(pwd)"/gost
    rm -rf "$(pwd)"/gost.service
    rm -rf "$(pwd)"//gost.yaml
    rm -rf "$(pwd)"/gost.sh
  fi
}
function update_gost() {
    version=$1
    get_download_url="$base_url/tags/$version"
    download_url=$(curl -s "$get_download_url" | grep -Eo "\"browser_download_url\": \".*${os}.*${cpu_arch}.*\"" | awk -F'["]' '{print $4}')
    # Download the binary
    echo "Downloading gost version $version..."
    curl -fsSL -o gost.tar.gz $download_url
    # Extract and install the binary
    echo "Installing gost..."
    tar -xzf gost.tar.gz
    chmod +x gost
    mv gost /usr/bin/gost
    chmod -R 777 /usr/bin/gost
}

# Check if --install option provided
if [[ "$1" == "--install" ]]; then
    # Install the latest version automatically
    if test -a /usr/bin/gost -a /usr/lib/systemd/system/gost.service -a /etc/gost/config.json; then
    echo "gost already installed"
    ver=$(gost -V | awk '{print $2}')
    if [ ! $(echo $latest_version | grep $ver) ]; then
    echo "not latest_ver"
    mv /usr/lib/systemd/system/gost.service /usr/lib/systemd/system/gost.service.bak
    mv /etc/gost/gost.yaml /etc/gost/gost.yaml.bak
    install_gost $latest_version
    else
    echo "already latest_ver"
    fi
  fi
else
    # Display available versions to the user
    echo "Available gost versions:"
    select version in $versions; do
        if [[ -n $version ]]; then
            install_gost $version
            break
        else
            echo "Invalid choice! Please select a valid option."
        fi
    done
fi
