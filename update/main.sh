#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR
source load_config.sh

echo "-------------------------------------------------------------"
echo "Main Update Script"
echo "-------------------------------------------------------------"

type=$1
firmware=$2
serial_port=$3

datestr=$(date)

echo "Date:" $datestr
echo "EUID: $EUID"
echo "openenergymonitor_dir: $openenergymonitor_dir"
echo "type: $type"
echo "firmware: $firmware"

if [ "$EUID" = "0" ] ; then
    # update is being ran mistakenly as root, switch to user
    echo "update running as root, switch to user"
    exit 0
fi

if [ "$emonSD_pi_env" = "1" ]; then
    # Check if we have an emonpi LCD connected, 
    # if we do assume EmonPi hardware else assume RFM69Pi
    lcd27=$(sudo $openenergymonitor_dir/emonpi/lcd/emonPiLCD_detect.sh 27 1)
    lcd3f=$(sudo $openenergymonitor_dir/emonpi/lcd/emonPiLCD_detect.sh 3f 1)

    if [ $lcd27 == 'True' ] || [ $lcd3f == 'True' ]; then
        hardware="EmonPi"
    else
        hardware="rfm2pi"
    fi
    echo "Hardware detected: $hardware"
    
    if [ "$hardware" == "EmonPi" ]; then    
        # Stop emonPi LCD servcice
        echo "Stopping emonPiLCD service"
        sudo systemctl stop emonPiLCD

        # Display update message on LCD
        echo "Display update message on LCD"
        sudo $openenergymonitor_dir/emonpi/lcd/./emonPiLCD_update.py
    fi
    
    # Ensure logrotate configuration has correct permissions
    sudo chown root:pi $openenergymonitor_dir/EmonScripts/defaults/etc/logrotate.d/*

fi

if [ "$type" == "all" ] || [ "$type" == "emonhub" ]; then
    echo "Running apt-get update"
    sudo apt-get update
fi

# -----------------------------------------------------------------

if [ "$type" == "all" ]; then
    sudo rm -rf hardware/emonpi/emonpi2c/

    for repo in "emonpi" "RFM2Pi" "usefulscripts" "huawei-hilink-status" "oem_openHab" "oem_node-red"; do
        if [ -d $openenergymonitor_dir/$repo ]; then
            echo "git pull $openenergymonitor_dir/$repo"
            cd $openenergymonitor_dir/$repo
            git branch
            git status
            git fetch --all --prune
            git pull
        fi
    done
fi
cd $openenergymonitor_dir/EmonScripts/update

# -----------------------------------------------------------------

if [ "$type" == "all" ] || [ "$type" == "firmware" ]; then

    if [ "$firmware" == "emonpi" ]; then
        $openenergymonitor_dir/EmonScripts/update/emonpi.sh
    fi

    if [ "$firmware" == "rfm69pi" ]; then
        $openenergymonitor_dir/EmonScripts/update/rfm69pi.sh
    fi
    
    if [ "$firmware" == "rfm12pi" ]; then
        $openenergymonitor_dir/EmonScripts/update/rfm12pi.sh
    fi
    
    if [ "$firmware" == "emontxv3cm" ]; then
        $openenergymonitor_dir/EmonScripts/update/emontxv3cm.sh $serial_port
    fi
fi

# -----------------------------------------------------------------

if [ "$type" == "all" ] || [ "$type" == "emonhub" ]; then
    echo "Start emonhub update script:"
    $openenergymonitor_dir/EmonScripts/update/emonhub.sh
    echo
fi

# -----------------------------------------------------------------

if [ "$type" == "all" ] || [ "$type" == "emoncms" ]; then    
    echo "Start emoncms update:"
    $openenergymonitor_dir/EmonScripts/update/emoncms_core.sh
    $openenergymonitor_dir/EmonScripts/update/emoncms_modules.sh
    echo
fi

# -----------------------------------------------------------------

if [ "$type" == "all" ] && [ "$emonSD_pi_env" = "1" ]; then  
    $openenergymonitor_dir/EmonScripts/update/emonsd.sh
fi

# -----------------------------------------------------------------

datestr=$(date)

echo
echo "-------------------------------------------------------------"
echo "emonPi update done: $datestr" # this text string is used by service runner to stop the log window polling, DO NOT CHANGE!
echo "-------------------------------------------------------------"

# -----------------------------------------------------------------

if [ "$type" == "all" ] || [ "$type" == "emoncms" ]; then
    echo "restarting service-runner"
    sudo systemctl restart service-runner.service 
fi
