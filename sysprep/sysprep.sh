#!/bin/bash

############################################################################
# Ubuntu VM Sysprep Script
#
# Created by: Brian Hill
# Version 0.1 - September 1, 2022
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
############################################################################

# Script version. Used for auto-updating from git repository.
ver="0.1"
