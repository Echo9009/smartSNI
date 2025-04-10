#!/bin/bash

#colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
rest='\033[0m'
myip=$(hostname -I | awk '{print $1}')

# Function to detect Linux distribution
detect_distribution() {
    local supported_distributions=("ubuntu" "debian" "centos" "fedora")
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ "${ID}" = "ubuntu" || "${ID}" = "debian" || "${ID}" = "centos" || "${ID}" = "fedora" ]]; then
            pm="apt"
            [ "${ID}" = "centos" ] && pm="yum"
            [ "${ID}" = "fedora" ] && pm="dnf"
        else
            echo "Unsupported distribution!"
            exit 1
        fi
    else
        echo "Unsupported distribution!"
        exit 1
    fi
}

# Install necessary packages
install_dependencies() {
    detect_distribution
    $pm update -y
    local packages=("nginx" "git" "jq" "certbot" "python3-certbot-nginx" "wget" "tar")
    
    echo -e "${cyan}Installing Advanced Gaming Network Optimizer Dependencies...${rest}"
    for package in "${packages[@]}"; do
        if ! dpkg -s "$package" &> /dev/null; then
            echo -e "${yellow}$package is not installed. Installing...${rest}"
            $pm install -y "$package"
        else
            echo -e "${green}$package is already installed.${rest}"
        fi
    done
    
    if ! command -v go &> /dev/null; then
        install_go
    else
        echo -e "${green}go is already installed.${rest}"
    fi
}

# Install Go
install_go() {
    echo -e "${yellow}go is not installed. Installing...${rest}"
    
    ARCH=$(dpkg --print-architecture)
    
    if [[ $ARCH == "amd64" || $ARCH == "arm64" ]]; then
        wget https://go.dev/dl/go1.21.1.linux-"$ARCH".tar.gz
        rm -rf /usr/local/go && rm -rf /usr/local/bin/go && tar -C /usr/local -xzf go1.21.1.linux-"$ARCH".tar.gz
        export PATH=$PATH:/usr/local/go/bin
        cp /usr/local/go/bin/go /usr/local/bin
        
        rm go1.21.1.linux-"$ARCH".tar.gz
        rm -rf /root/go
        echo -e "${cyan}Go has been installed.${rest}"
    else
        echo -e "${red}Unsupported architecture: $ARCH${rest}"
        exit 1
    fi
}

# install SNI service
install() {
    if systemctl is-active --quiet sni.service; then
        echo -e "${yellow}╔══════════════════════╗${rest}"
        echo -e "${yellow}║${rest} ${green}Gaming Network Optimizer${rest} ${yellow}║${rest}"
        echo -e "${yellow}║${rest} ${green}Already Active${rest}         ${yellow}║${rest}"
        echo -e "${yellow}╚══════════════════════╝${rest}"
    else
        install_dependencies
        git clone https://github.com/Echo9009/smartSNI.git /root/smartSNI
         
        sleep 1
        clear
        echo -e "${purple}╔════════════════════════════════════╗${rest}"
        echo -e "${purple}║${rest}    ${cyan}GAMING NETWORK OPTIMIZER SETUP${rest}    ${purple}║${rest}"
        echo -e "${purple}╚════════════════════════════════════════════════╝${rest}"
        
        echo -e "${yellow}╔══════════════════════╗${rest}"
        read -p "║ Enter your domain: " domain
        echo -e "${yellow}╚══════════════════════╝${rest}"
        
        # Create a JSON Object with host and wildcard domain (dot matches all domains)
        json_content="{ \"host\": \"$domain\", \"domains\": { \".\": \"$myip\" } }"
        
        # Save JSON to config.json file
        echo "$json_content" | jq '.' > /root/smartSNI/config.json

        nginx_conf="/etc/nginx/sites-enabled/default"
        sed -i "s/server_name _;/server_name $domain;/g" "$nginx_conf"
        sed -i "s/<YOUR_HOST>/$domain/g" /root/smartSNI/nginx.conf

        # Obtain SSL certificates
        certbot --nginx -d $domain --register-unsafely-without-email --non-interactive --agree-tos --redirect

        sudo cp /root/smartSNI/nginx.conf "$nginx_conf"
        systemctl stop nginx
        systemctl restart nginx

        config_file="/root/smartSNI/config.json"

        sed -i "s/<YOUR_HOST>/$domain/g" "$config_file"
        sed -i "s/<YOUR_IP>/$myip/g" "$config_file"
        
        # Create systemd service file
        cat > /etc/systemd/system/sni.service <<EOL
[Unit]
Description=Smart SNI Service

[Service]
User=root
WorkingDirectory=/root/smartSNI
ExecStart=/usr/local/go/bin/go run /root/smartSNI/main.go
Restart=always

[Install]
WantedBy=default.target
EOL

        # Reload systemd, enable and start the service
        systemctl daemon-reload
        systemctl enable sni.service
        systemctl start sni.service

        # Check if the service is active
        if systemctl is-active --quiet sni.service; then
            echo -e "${green}╔═════════════════════════════════════════╗${rest}"
            echo -e "${green}║${rest}  ${cyan}GAMING NETWORK OPTIMIZER ACTIVATED${rest}  ${green}║${rest}"
            echo -e "${green}╠═════════════════════════════════════════╣${rest}"
            echo -e "${green}║${rest} ${yellow}• Universal access to ALL domains${rest}      ${green}║${rest}"
            echo -e "${green}║${rest} ${yellow}• No whitelist restrictions${rest}            ${green}║${rest}"
            echo -e "${green}║${rest} ${yellow}• Maximum gaming compatibility${rest}         ${green}║${rest}"
            echo -e "${green}╠═════════════════════════════════════════╣${rest}"
            echo -e "${green}║${rest} ${cyan}DOH --> https://$domain/dns-query${rest}  ${green}║${rest}"
            echo -e "${green}╚══════════════════════════════════════════╝${rest}"
        else
            echo -e "${red}╔═════════════════════════╗${rest}"
            echo -e "${red}║${rest} ${yellow}Service Activation Failed${rest} ${red}║${rest}"
            echo -e "${red}╚══════════════════════════╝${rest}"
        fi
    fi
}

# Uninstall function
uninstall() {
    if [ ! -f "/etc/systemd/system/sni.service" ]; then
        echo -e "${yellow}____________________________${rest}"
        echo -e "${red}The service is not installed.${rest}"
        echo -e "${yellow}____________________________${rest}"
        return
    fi
    # Stop and disable the service
    sudo systemctl stop sni.service
    sudo systemctl disable sni.service 2>/dev/null

    # Remove service file
    sudo rm /etc/systemd/system/sni.service
    rm -rf /root/smartSNI
    rm -rf /root/go
    echo -e "${yellow}____________________________________${rest}"
    echo -e "${green}Uninstallation completed successfully.${rest}"
    echo -e "${yellow}____________________________________${rest}"
}

# Show Websites
display_sites() {
    if [ -d "/root/smartSNI" ]; then
        echo -e "${blue}╔═════════════════════════════════════════╗${rest}"
        echo -e "${blue}║${rest}   ${cyan}UNIVERSAL DOMAIN ACCESS ENABLED${rest}   ${blue}║${rest}"
        echo -e "${blue}╠═══════════════════════════════════════════════════╝${rest}"
        echo -e "${blue}║${rest} ${green}All domains are automatically proxied${rest} ${blue}║${rest}"
        echo -e "${blue}║${rest} ${green}No whitelist restrictions applied${rest}    ${blue}║${rest}"
        echo -e "${blue}╚═════════════════════════════════════════╝${rest}"
    else
        echo -e "${red}╔═════════════════════════════════════╗${rest}"
        echo -e "${red}║${rest} ${yellow}Gaming Optimizer Not Installed${rest}      ${red}║${rest}"
        echo -e "${red}║${rest} ${yellow}Please run installation first${rest}       ${red}║${rest}"
        echo -e "${red}╚══════════════════════════════════════════╝${rest}"
    fi
}

# Add sites - not needed with universal access
add_sites() {
    if [ -d "/root/smartSNI" ]; then
        echo -e "${blue}╔═════════════════════════════════════════╗${rest}"
        echo -e "${blue}║${rest}   ${cyan}UNIVERSAL DOMAIN ACCESS ENABLED${rest}   ${blue}║${rest}"
        echo -e "${blue}╠═════════════════════════════════════════╣${rest}"
        echo -e "${blue}║${rest} ${green}All domains are already accessible${rest}   ${blue}║${rest}"
        echo -e "${blue}║${rest} ${green}No need to add specific domains${rest}      ${blue}║${rest}"
        echo -e "${blue}╚═════════════════════════════════════════╝${rest}"
    else
        echo -e "${red}╔═════════════════════════════════════╗${rest}"
        echo -e "${red}║${rest} ${yellow}Gaming Optimizer Not Installed${rest}      ${red}║${rest}"
        echo -e "${red}║${rest} ${yellow}Please run installation first${rest}       ${red}║${rest}"
        echo -e "${red}╚══════════════════════════════════════════╝${rest}"
    fi
}

# Remove sites - not needed with universal access
remove_sites() {
    if [ -d "/root/smartSNI" ]; then
        echo -e "${blue}╔═════════════════════════════════════════╗${rest}"
        echo -e "${blue}║${rest}   ${cyan}UNIVERSAL DOMAIN ACCESS ENABLED${rest}   ${blue}║${rest}"
        echo -e "${blue}╠═════════════════════════════════════════╣${rest}"
        echo -e "${blue}║${rest} ${green}All domains are accessible by default${rest} ${blue}║${rest}"
        echo -e "${blue}║${rest} ${green}No domain restrictions to remove${rest}      ${blue}║${rest}"
        echo -e "${blue}╚═════════════════════════════════════════╝${rest}"
    else
        echo -e "${red}╔═════════════════════════════════════╗${rest}"
        echo -e "${red}║${rest} ${yellow}Gaming Optimizer Not Installed${rest}      ${red}║${rest}"
        echo -e "${red}║${rest} ${yellow}Please run installation first${rest}       ${red}║${rest}"
        echo -e "${red}╚══════════════════════════════════════════╝${rest}"
    fi
}

config_file="/root/smartSNI/config.json"

    if [ -d "/root/smartSNI" ]; then
        echo -e "${blue}╔═════════════════════════╗${rest}"
        echo -e "${blue}║${rest}   ${cyan}OPTIMIZED GAME SERVERS${rest}   ${blue}║${rest}"
        echo -e "${blue}╠═══════════════════════════╣${rest}"
        
        # Initialize a counter
        counter=1
        # Loop through the domains and display with numbering
        jq -r '.domains | keys_unsorted | .[]' "$config_file" | while read -r domain; do
            printf "${blue}║${rest} %2d) %-20s ${blue}║${rest}\n" "$counter" "$domain"
            ((counter++))
        done
        
        echo -e "${blue}╚═══════════════════════════╝${rest}"
    else
        echo -e "${red}╔═════════════════════════════════════╗${rest}"
        echo -e "${red}║${rest} ${yellow}Gaming Optimizer Not Installed${rest}      ${red}║${rest}"
        echo -e "${red}║${rest} ${yellow}Please run installation first${rest}       ${red}║${rest}"
        echo -e "${red}╚══════════════════════════════════════════╝${rest}"
    fi
}

# Check service
check() {
    if systemctl is-active --quiet sni.service; then
        echo -e "${cyan}[Service Actived]${rest}"
    else
        echo -e "${yellow}[Service Not Active]${rest}"
    fi
}

# Add sites
add_sites() {
    config_file="/root/smartSNI/config.json"

    if [ -d "/root/smartSNI" ]; then
        echo -e "${yellow}********************${rest}"
        read -p "Enter additional Websites (separated by commas):" additional_sites
        IFS=',' read -ra new_sites <<< "$additional_sites"

        current_domains=$(jq -r '.domains | keys_unsorted | .[]' "$config_file")
        for site in "${new_sites[@]}"; do
            if [[ ! " ${current_domains[@]} " =~ " $site " ]]; then
                jq ".domains += {\"$site\": \"$myip\"}" "$config_file" > temp_config.json
                mv temp_config.json "$config_file"
                echo -e "${yellow}********************${rest}"
                echo -e "${green}Domain ${cyan}'$site'${green} added successfully.${rest}"
            else
                echo -e "${yellow}Domain ${cyan}'$site' already exists.${rest}"
            fi
        done

        # Restart the service
        systemctl restart sni.service
    else
        echo -e "${yellow}********************${rest}"
        echo -e "${red}Not installed. Please Install first.${rest}"
    fi
}

# Remove sites
remove_sites() {
    config_file="/root/smartSNI/config.json"

    if [ -d "/root/smartSNI" ]; then
        # Display available sites
        display_sites
        
        read -p "Enter Websites names to remove (separated by commas): " domains_to_remove
        IFS=',' read -ra selected_domains <<< "$domains_to_remove"

        # Remove selected domains from JSON
        for selected_domain in "${selected_domains[@]}"; do
            if jq -e --arg selected_domain "$selected_domain" '.domains | has($selected_domain)' "$config_file" > /dev/null; then
                jq "del(.domains[\"$selected_domain\"])" "$config_file" > temp_config.json
                mv temp_config.json "$config_file"
                echo -e "${yellow}********************${rest}"
                echo -e "${green}Domain ${cyan}'$selected_domain'${green} removed successfully.${rest}"
            else
                echo -e "${yellow}********************${rest}"
                echo -e "${yellow}Domain ${cyan}'$selected_domain'${yellow} not found.${rest}"
            fi
        done

        # Restart the service
        systemctl restart sni.service
    else
        echo -e "${yellow}********************${rest}"
        echo -e "${red}Not installed. Please Install first.${rest}"
    fi
}

clear
echo -e "${cyan}╔═════════════════════╗${rest}"
echo -e "${cyan}║${rest} ${green}GAMING OPTIMIZER MENU${rest} ${purple}║${rest}"
echo -e "${cyan}╠═════════════════════╣${rest}"
echo -e "${cyan}║${rest} ${yellow}1]${rest} ${green}Install Optimizer${rest}   ${purple}║${rest}"
echo -e "${cyan}║${rest} ${yellow}2]${rest} ${green}Uninstall${rest}           ${purple}║${rest}"
echo -e "${cyan}║${rest} ${yellow}3]${rest} ${green}Check Status${rest}        ${purple}║${rest}"
echo -e "${cyan}║${rest} ${red}0${yellow}]${rest} ${purple}Exit${rest}               ${purple}║${rest}"
echo -e "${cyan}╚═════════════════════╝${rest}"
read -p "Enter your choice: " choice
case "$choice" in
    1)
        install
        ;;
    2)
        uninstall
        ;;
    3) 
        display_sites
        ;;
    4) 
        add_sites
        ;;
    5)
        remove_sites
        ;;
    0)
        echo -e "${cyan}By 🖐${rest}"
        exit
        ;;
    *)
        echo -e "${yellow}********************${rest}"
        echo "Invalid choice. Please select a valid option."
        ;;
esac