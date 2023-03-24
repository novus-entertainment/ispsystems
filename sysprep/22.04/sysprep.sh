#!/bin/bash

###################################################################################################
# Ubuntu 22.04 Sysprep Script
#
# Created by: Brian Hill
# Version 0.1 - March 24, 2023
#
# Run this script to configure the newly deployed VM.
#    - Check for script update and restart script if found
#    - Set hostname
#    - Set timezone
#    - Configuire network interfaces
#    - Configure stock firewall rules
#    - Update system
#    - Install common utilities
#    - Join Active Directory
#    - Install Zabbix Agent 2 (Active)
###################################################################################################

# Script version. Used for auto-updating from git repository.
ver="0.1"

# Reset all screen formatting and clear screen
printf "\033[0m"
clear


###################################################################################################
##      Sysprep Auto-Update Function
##          Called at run of script and after network configuration completed
###################################################################################################

auto_update () {
    # Check if updated variable is true
    if [ -z "$updated" ]
    then
        # Check if machine has access to the internet by querying connection to google.ca
        wget -q --inet4-only --tries=10 --timeout=20 --spider https://google.ca
        if [[ $? -eq 0 ]]
        then
            internet=true
        else
            internet=false
        fi

        if [ "$internet" = true ]
        then
            # Download script from GitHub repo
            curl https://raw.githubusercontent.com/novus-entertainment/ispsystems/main/sysprep/22.04/sysprep.sh --output /root/sysprep_temp.sh &>/dev/null

            # Check version of downloaded script
            version=$(awk -F'"' '/^ver=/ {print $2}' sysprep_temp.sh)

            # If newer delete old sysprep.sh and replace with updated one
            if [ "$version" != "$ver" ]
            then
                rm /root/sysprep.sh
                mv /root/sysprep_temp.sh /root/sysprep.sh
                chmod +x /root/sysprep.sh

                # Set updated variable as true
                updated=true

                # Restart sysprep script
                printf "\033[1;31mA new version of the Sysprep script has been downloaded. Restarting the script in 5 seconds.\n\n\033[0m"
                sleep 5
                exec /root/sysprep.sh
            else
                rm /root/sysprep_temp.sh
                printf "\033[1;32mAlready running latest version of Sysprep script.\033[0m\n\n"
                # Set updated variable as true
                updated=true
            fi
        fi
    fi
}

auto_update

###################################################################################################
##      Set hostname
###################################################################################################
unset hostnamevar
hostnamevar=$(hostname)
# Prompt for new hostname
printf "\033[1;37mPlease specify hostname [${hostnamevar}]: \033[0m"
read hostnamenew
if [ -z $hostnamenew ]
then
    # Use current system hostname    
    hostnamevar=$hostnamevar
else
    hostnamevar=$hostnamenew
fi

# Set hostname
hostnamectl set-hostname $hostnamevar
printf "\033[1;32mHostname set to ${hostnamevar}\033[0m\n\n"

# Write hostname into /etc/hosts file
sed -i "s/127.0.1.1.*/127.0.1.1 $(hostname)/g" /etc/hosts


###################################################################################################
##      Set timezone
###################################################################################################
unset timezonevar
printf "\033[1;37mPlease specify timezone [America/Vancouver]: \033[0m"
read timezonevar
if [ -z $timezonevar ]
then
    timezonevar="America/Vancouver"
    timedatectl set-timezone $timezonevar
else
    timedatectl set-timezone $timezonevar
fi
printf "\033[1;32mTimezone set to ${timezonevar}\033[0m\n\n"


###################################################################################################
##      Configure network interfaces
###################################################################################################

# Function to test IP address with CIDR
test_cidr () {
	IFS='./' read -r a b c d e <<< $1

	for var in "$a" "$b" "$c" "$d" "$e"; do
		case $var in
			""|*[!0123456789]*) 
				printf "Invalid CIDR format IP address entered: $cidr\n"
				network_config
		esac
	done

	ipaddr="$a.$b.$c.$d/$e"

	if [ "$a" -ge 0 ] && [ "$a" -le 255 ] &&
	   [ "$b" -ge 0 ] && [ "$b" -le 255 ] &&
	   [ "$c" -ge 0 ] && [ "$c" -le 255 ] &&
	   [ "$d" -ge 0 ] && [ "$d" -le 255 ] &&
	   [ "$e" -ge 0 ] && [ "$e" -le 32  ]
	then
		printf '"%s" is a valid CIDR address\n' "$ipaddr"
	else
		printf '"%s" is not a valid CIDR address\n' "$ipaddr"
		network_config
	fi
}

# Function to test IP address without CIDR
test_ip () {
	IFS='./' read -r a b c d <<< $1

	for var in "$a" "$b" "$c" "$d"; do
		case $var in
			""|*[!0123456789]*) 
				printf "Invalid CIDR format IP address entered: $cidr\n"
				network_config
		esac
	done

	ipaddr="$a.$b.$c.$d/$e"

	if [ "$a" -ge 0 ] && [ "$a" -le 255 ] &&
	   [ "$b" -ge 0 ] && [ "$b" -le 255 ] &&
	   [ "$c" -ge 0 ] && [ "$c" -le 255 ] &&
	   [ "$d" -ge 0 ] && [ "$d" -le 255 ]
	then
		printf '"%s" is a valid IP address\n' "$ipaddr"
	else
		printf '"%s" is not a valid IP address\n' "$ipaddr"
		network_config
	fi
}

# Option to configure network settings
network_config () {
printf "\033[1;37mConfigure network settings?\n\033[0m"
select confignet in Yes No
do
	case $confignet in
		"Yes")
			# Delete old netplan files
			rm -f /etc/netplan/*

			unset interfaces

			# Get array of interface names
			interfaces=( $(ip link | awk -F: '$0 !~ "lo|vir|^[^0-9]"{print $2a;getline}') )

			# Prompt user for settings for each interface detected and write to netplan config file
			for interface in ${interfaces[@]}; do
				printf "\033[1;33mSpecify settings for network interface: ${interface}\n\033[0m"

				# Ask if IPv6 support is wanted
				printf "\033[1;37mDoes this interface need IPv6 configured?\n\033[0m"
				select v6 in Yes No
				do
					case $v6 in
						"Yes")
							v6support=true
							break
							;;
						"No")
							v6support=false
							break
							;;
						*)
							printf "\033[1;31mPlease select Yes or No.\n\n\033[0m";;
					esac
				done

				unset type

				printf "\n"
				printf "\033[1;37mSelect interface type:\n\033[0m"
				select type in DHCP Static
				do
					case $type in
						"DHCP")
							# Write DHCP settings to interface config file
							if [ $v6support = true ]
							then
							# IPv6 support wanted
							cat > /etc/netplan/${interface}.yaml <<EOF
network:
  version: 2
  ethernets:

    ${interface}:
      optional: true
      accept-ra: true
      dhcp4: true
      dhcp6: true

EOF
				else
				# No IPv6 support wanted
				cat > /etc/netplan/${interface}.yaml <<EOF
network:
  version: 2
  ethernets:

    ${interface}:
      optional: true
      accept-ra: false
      dhcp4: true
      dhcp6: false

EOF
							fi
							printf "\n\n"
							break
							;;
						"Static")
							if [ $v6support = true ]
							then
								# IPv6 support wanted
								printf "\033[1;37mEnter IPv4 address in CIDR format. Eg: 192.168.66.20/24: \033[0m"
								read ip
								test_cidr $ip
								printf "\033[1;37mEnter IPv6 address in CIDR format. Eg: 2605:1700:1:2011::20/64: \033[0m"
								read ip6
								printf "\033[1;37mEnter IPv4 gateway address: \033[0m"
								read gw
								test_ip $gw
								printf "\033[1;37mEnter IPv6 gateway address: \033[0m"
								read gw6
								printf "\033[1;37mEnter comma separated list of nameservers: \033[0m"
								read dns

								# Validate IP's entered
								
								
								# Write Static IP settings to interface config file
								cat > /etc/netplan/${interface}.yaml <<EOF
network:
  version: 2
  ethernets:

    ${interface}:
      optional: true
      accept-ra: true
      addresses:
          - ${ip}
          - ${ip6}
      nameservers:
          search: [novusnow.local]
          addresses: [${dns}]
      routes:
        - to: default
          via: ${gw}
        - on-link: true
          to: ::/0
          via: ${gw6}
EOF

								# Comment out un-needed netplan settings
								if [ -z $gw ]
								then
									sed -i "s/      gateway4/#      gateway4/" /etc/netplan/${interface}.yaml
								fi
								if [ -z $gw6 ]
								then
									sed -i "s/      gateway6/#      gateway6/" /etc/netplan/${interface}.yaml
								fi
								if [ -z $dns ]
								then
									sed -i "s/          addresses/#          addresses/" /etc/netplan/${interface}.yaml
								fi
							else
								# No IPv6 support wanted
								printf "\033[1;37mEnter IPv4 address in CIDR format. Eg: 192.168.66.20/24: \033[0m"
								read ip
								test_cidr $ip
								printf "\033[1;37mEnter gateway address: \033[0m"
								read gw
								test_ip $gw
								printf "\033[1;37mEnter comma separated list of nameservers: \033[0m"
								read dns

								# Write Static IP settings to interface config file
								cat > /etc/netplan/${interface}.yaml <<EOF
network:
  version: 2
  ethernets:

    ${interface}:
      optional: true
      accept-ra: false
      link-local: []
      addresses:
          - ${ip}
      nameservers:
          search: [novusnow.local]
          addresses: [${dns}]
      routes:
        - to: default
          via: ${gw}
EOF

								# Comment out un-needed netplan settings
								if [ -z $gw ]
								then
									sed -i "s/      gateway4/#      gateway4/" /etc/netplan/${interface}.yaml
								fi
								if [ -z $dns ]
								then
									sed -i "s/          addresses/#          addresses/" /etc/netplan/${interface}.yaml
								fi

							fi
							break
							;;
						*)
							printf "Invalid selection ${REPLY}\n\n"
							break
							;;
					esac
				done
			done

			# Apply netplan configuration
			netplan apply

			# Sleep for 5 seconds to wait for interfaces to come up
			sleep 5
			printf "\n\n"

			# Check for Sysprep script updates
			auto_update

			break
			;;
		"No")
			# Skip network configuration
			printf "\033[1;33mNetwork configuration skipped.\n\033[0m"
			break
			;;
		*)
			printf "\033[1;31mPlease select Yes or No.\n\n\033[0m";;
	esac
done
}

network_config

###################################################################################################
##      Configure UFW Firewall
###################################################################################################
# Skip firewall configuration if network configuration was skipped.
if [ $confignet = Yes ]
then
    if [ $v6support = true ]
    then
        # Enable IPv6 rule generation in UFW default config
        sed -i "s/IPV6=no/IPV6=yes/" /etc/default/ufw
    else
        # Disable IPv6 rule generation in UFW default config
        sed -i "s/IPV6=yes/IPV6=no/" /etc/default/ufw
    fi

    # Set default inbound behavior to block
    ufw default deny &>/dev/null

    # Allow SSH
    ufw allow 22/tcp comment 'SSH service' &>/dev/null
    
    # Enable UFW Firewall
    ufw enable &>/dev/null
fi

###################################################################################################
##      Update OS
###################################################################################################
printf "\n\n"
printf "\033[1;37mInstalling OS updates, please wait...\n\033[0m"
pro config set apt_news=false
apt update
apt upgrade -y

# Remove packages that are no longer required
apt autoremove -y


###################################################################################################
##      Install common utilities
###################################################################################################
printf "\n\n"
printf "\033[1;37mInstalling common utilities, please wait\n\033[0m"
apt install -y git neofetch pv


# Add neofetch to .bashrc to display summary after login
checkneofetch=$(grep '/etc/skel/.bashrc' -e 'neofetch')
if [[ -z ${checkneofetch} ]]
then
   cat >> /etc/skel/.bashrc <<EOF
neofetch
EOF

    cat >> /home/admin/.bashrc <<EOF
neofetch
EOF
fi

###################################################################################################
##      Join Active Directory
###################################################################################################
printf "\n\n"
printf "\033[1;37mDo you want to join this machine to Active Directory?\n\033[0m"
select ad in Yes No
do
    case $ad in
        "Yes")
            # Install required packages
            printf "\n\n"
            printf "\033[1;37mInstalling packages needed to join AD, please wait...\033[0m"
            apt -y install realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

            # Discover the NOVUSNOW.LOCAL domain
            realm -v discover novusnow.local

            # Prompt for OU to place Computer Object into
            printf "\033[1;37mWhich OU should this Computer Object be created in?\n\033[0m"
            select ad_ou in Internal External
            do
                case $ad_ou in
                    "Internal")
                        ou_path="Internal Facing"
                        break
                        ;;
                    "External")
                        ou_path="External Facing"
                        break
                        ;;
                esac
            done

            # Prompt for AD join username
            printf "\n\n"
            printf "\033[1;37mPlease enter AD user to perform join function as: \033[0m"
            read aduser
            realm join -v --computer-ou="OU=${ou_path},OU=Servers,DC=novusnow,DC=local" --automatic-id-mapping=no -U $aduser NOVUSNOW.LOCAL
            
            # Modify /etc/pam.d/common-session to create AD user's local home folder on first login
            cat >> /etc/pam.d/common-session <<EOF
# Create Home Dir automatically after initial login
session optional        pam_mkhomedir.so skel=/etc/skel umask=077
EOF

            # Create SSSD config file. Restrict login to "ISP Server Admins" AD group.
            :> /etc/sssd/sssd.conf
            cat > /etc/sssd/sssd.conf <<EOF
[sssd]
domains = novusnow.local
config_file_version = 2
services = nss, pam

[domain/novusnow.local]
default_shell = /bin/bash
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = NOVUSNOW.LOCAL
realmd_tags = manages-system joined-with-adcli
id_provider = ad
fallback_homedir = /home/%u
ad_domain = novusnow.local
use_fully_qualified_names = False
ldap_id_mapping = True
access_provider = simple
simple_allow_groups = ISP Server Admins
EOF

            # Restart SSSD service to have changes take effect
            printf "Restarting services\n"
            systemctl restart sssd

            # Allow specific AD groups to have SUDO permission
            cat >> /etc/sudoers <<EOF
# Active Directory Groups
%isp\ server\ admins     ALL=(ALL)       NOPASSWD: ALL
EOF
            break
            ;;
        "No")
            break
            ;;
        *)
            printf "\033[1;31mPlease select Yes or No.\n\n\033[0m";;
    esac
done

printf "\n\n"

###################################################################################################
##      Install Zabbix Agent
###################################################################################################
printf "\033[1;37mDo you want this machine to be monitored by Zabbix?\n\033[0m"
select zabbix in Yes No
do
    case $zabbix in
        "Yes")
            printf "\033[1;37m\nAdding Zabbix repository and installing packages, please wait...\n\033[0m"
            
            # Add official repository
            wget --inet4-only https://repo.zabbix.com/zabbix/6.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.2-4+ubuntu22.04_all.deb
            dpkg -i zabbix-release_6.2-4+ubuntu22.04_all.deb

            # Install Zabbix Agent 2
            apt update &>/dev/null
            apt install zabbix-agent2

            # Stop agent and enable service
            systemctl stop zabbix-agent2
            systemctl enable zabbix-agent2

            # Prompt for Zabbix Server to register to
            printf "\033[1;37mWhich Zabbix server should this VM register to?\n\033[0m"
            select zabbix_server in Systems Mediaroom Network-Core Network-Access
            do
                case $zabbix_server in
                    "Systems")
                        server=192.168.66.25
                        break
                        ;;
                    "Mediaroom")
                        server=10.252.100.13
                        break
                        ;;
                    "Network-Core")
                        server=192.168.66.44
                        break
                        ;;
                    "Network-Access")
                        server=192.168.66.71
                        break
                        ;;
                esac
            done

            # Download Zabbix Agent2 config file from git repo
            mv /etc/zabbix/zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf.bak
            curl https://raw.githubusercontent.com/novus-entertainment/ispsystems/main/zabbix/config/agent/ubuntu22.04/zabbix_agent2.conf --output /etc/zabbix/zabbix_agent2.conf

            # Modify server setting in config file
            sed -i "s/^Server=/Server=${server}/" /etc/zabbix/zabbix_agent2.conf
            sed -i "s/^ServerActive=/ServerActive=${server}/" /etc/zabbix/zabbix_agent2.conf

            # Wait 5 seconds before starting Zabbix Agent2 service
            sleep 5
            systemctl start zabbix-agent2

            # Cleanup installer files
            rm -rf /root/zabbix-release_*

            # Add firewall rule
            ufw allow 10050/tcp comment 'Zabbix Agent2'

            break
            ;;
        "No")
            # Do not install Zabbix Agent 2
            break
            ;;
        *)
            printf "\033[1;31mPlease select Yes or No.\n\n\033[0m";;
    esac
done

printf "\n\n"

###################################################################################################
##      Sysprep Complete - Prompt for reboot
###################################################################################################
printf "\n\n\n\033[1;32mSysprep script completed. A reboot is required. Reboot now?\n\033[0m"
select reboot in Yes No
do
    case $reboot in
        "Yes")
            # Reboot system
            shutdown -r now
            break
            ;;
        "No")
            # Inform user a system reboot is needed as soon as they can do it
            printf "\033[1;33mPlease reboot at your earliest convenience.\n\n\033[0m"
            break
            ;;
        *)
            printf "\033[1;31mPlease select Yes or No.\n\n\033[0m";;
    esac
done
