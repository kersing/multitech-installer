#!/bin/bash
#
# Script to update packages for TTN on MultiTech Linux Conduit
# 
# Written by Jac Kersing <j.kersing@the-box.com>
#
# Parts of the script based on tzselect by Paul Eggert.
#

STATUSFILE=/var/config/.installer
VERSION=2.1-r4
FILENAME=poly-packet-forwarder_${VERSION}_arm926ejste.ipk
#URL=https://raw.github.com/kersing/packet_forwarder/master/multitech-bin/${FILENAME}
URL=https://raw.github.com/kersing/multitech-installer/master/${FILENAME}

if [ ! -f $STATUSFILE ] ; then
	touch /var/config/.installer
fi

# now set the time zone
# Output one argument as-is to standard output.
# Safer than 'echo', which can mishandle '\' or leading '-'.
say() {
    printf '%s\n' "$1"
}

# Ask the user to select from the function's arguments,
# and assign the selected argument to the variable 'select_result'.
# Exit on EOF or I/O error.  Use the shell's 'select' builtin if available,
# falling back on a less-nice but portable substitute otherwise.
if
  case $BASH_VERSION in
  ?*) : ;;
  '')
    # '; exit' should be redundant, but Dash doesn't properly fail without it.
    (eval 'set --; select x; do break; done; exit') </dev/null 2>/dev/null
  esac
then
  # Do this inside 'eval', as otherwise the shell might exit when parsing it
  # even though it is never executed.
  eval '
    doselect() {
      select select_result
      do
	case $select_result in
	"") echo >&2 "Please enter a number in range." ;;
	?*) break
	esac
      done || exit
    }

    # Work around a bug in bash 1.14.7 and earlier, where $PS3 is sent to stdout.
    case $BASH_VERSION in
    [01].*)
      case `echo 1 | (select x in x; do break; done) 2>/dev/null` in
      ?*) PS3=
      esac
    esac
  '
else
  doselect() {
    # Field width of the prompt numbers.
    select_width=`expr $# : '.*'`

    select_i=

    while :
    do
      case $select_i in
      '')
	select_i=0
	for select_word
	do
	  select_i=`expr $select_i + 1`
	  printf >&2 "%${select_width}d) %s\\n" $select_i "$select_word"
	done ;;
      *[!0-9]*)
	echo >&2 'Please enter a number in range.' ;;
      *)
	if test 1 -le $select_i && test $select_i -le $#; then
	  shift `expr $select_i - 1`
	  select_result=$1
	  break
	fi
	echo >&2 'Please enter a number in range.'
      esac

      # Prompt and read input.
      printf >&2 %s "${PS3-#? }"
      read select_i || exit
    done
  }
fi

# Ask for location/configuration
grep location $STATUSFILE > /dev/null 2> /dev/null
if [ $? -ne 0  -a ! -f /var/config/lora/global_conf_src ] ; then
	echo "SETUP FREQUENCY PLAN"
	lora_id=$(mts-io-sysfs show lora/product-id 2> /dev/null)
	config=""
	if [ "$lora_id" == "MTAC-LORA-868" ] ; then
		echo "Detected 868MHz card, use TTN 868 configuation?"
		doselect Yes No
		if [ "$select_result" == "Yes" ] ; then
			config="https://raw.githubusercontent.com/TheThingsNetwork/gateway-conf/master/EU-global_conf.json"
		fi
	fi
	if [ X"$config" == X"" ] ; then
		echo "Please select the configuration:"
		doselect EU868 AU915 US915
		case $select_result in
			EU868)
				config="https://raw.githubusercontent.com/TheThingsNetwork/gateway-conf/master/EU-global_conf.json"
				;;
			AU915)
				config="https://raw.githubusercontent.com/TheThingsNetwork/gateway-conf/master/AU-global_conf.json"
				;;
			US915)
				config="https://raw.githubusercontent.com/TheThingsNetwork/gateway-conf/master/US-global_conf.json"
				;;
		esac
	fi
	echo "$config" > /var/config/lora/global_conf_src
	echo "location" >> $STATUSFILE
fi

# Create lora configuration directory and initial files
grep loraconf $STATUSFILE > /dev/null 2> /dev/null
if [ $? -ne 0 -a ! -f /var/config/lora/local_conf.json ] ; then
	if [ -f /var/config/lora/local_conf.json ] ; then
		mv /var/config/lora/local_conf.json /var/config/lora/local_conf.old
	fi
	got_it="No"
	while [ "$got_it" != "Yes" ] ; do
		echo "SETUP LORA GATEWAY CONFIGURATION"
		echo -n "E-mail address of gateway operator: "
		read email
		echo -n "Gateway description: "
		read descr
		echo "Include location information?"
		doselect Yes No
		if [ "$select_result" = "Yes" ] ; then
			echo "Gateway location information"
			echo -n "latitude: "
			read lat
			echo -n "longitude: "
			read lon
			echo -n "altitude: "
			read alt
		else
			lat=0
			lon=0
			alt=0
		fi
		echo ""
		echo "Your gateway information is:"
		echo "e-mail contact: $email"
		echo "description   : $descr"
		if [ X"$lat" != X"0" -o X"$lon" != X"0" ] ; then
			echo "Check Location: https://maps.google.com/?q=$lat,$lon"
		fi
		echo ""
		echo "Is the information correct?"
		doselect Yes No
		got_it=$select_result
	done
	gwid=$(mts-io-sysfs show lora/eui 2> /dev/null | sed 's/://g')
	if [ X"$gwid" == X"" ] ; then
		echo "FATAL ERROR: could not obtain gateway id, Lora card not found"
		exit 1
	fi

	cat << _EOF_ > /var/config/lora/local_conf.json
/* Settings defined in global_conf will be overwritten by those in local_conf */
    "gateway_conf": {
        /* you must pick a unique 64b number for each gateway (represented by an hex string) */
        "gateway_ID": "$gwid",
        /* Email of gateway operator, max 40 chars*/
        "contact_email": "$email", 
        /* Public description of this device, max 64 chars */
        "description": "$descr",
        /* Enter VALID GPS coordinates below before enabling fake GPS */
_EOF_
	if [ X"$lat" != X"0" -o X"$lon" != X"0" ] ; then
		echo '        "fake_gps": true,' >> /var/config/lora/local_conf.json
	else
		echo '        "fake_gps": false,' >> /var/config/lora/local_conf.json
	fi
	cat << _EOF_ >> /var/config/lora/local_conf.json
        "ref_latitude": $lat,
        "ref_longitude": $lon,
        "ref_altitude": $alt
    }
}
_EOF_
	echo "loraconf" >> $STATUSFILE
fi

# Disable the MultiTech lora server processes
# Do we want to remove the software as well??
grep disable-mtech $STATUSFILE > /dev/null 2> /dev/null
if [ $? -ne 0 ] ; then
	echo "Disable MultiTech packet forwarder"
	/etc/init.d/lora-network-server stop
	cat << _EOF_ > /etc/default/lora-network-server
# set to "yes" or "no" to control starting on boot
ENABLED="no"
_EOF_
	echo "disable-mtech" >> $STATUSFILE
fi

fnd=$(opkg list-installed poly-packet-forwarder)
version=$(echo $fnd | cut -d' ' -f 3)
if [ X"$version" != X"$VERSION" ] ; then
	echo "Installing TTN Poly Packet Forwarder"
	wget $URL -O /tmp/$FILENAME -o /dev/null --no-check-certificate
	opkg install /tmp/$FILENAME
fi

# Get global config
echo "Get up-to-date TTN configuration for packet forwarder"
read url < /var/config/lora/global_conf_src
wget $url -O /var/config/lora/ttn_global_conf.json -o /dev/null --no-check-certificate
if [ ! -f /var/config/lora/ttn_global_conf.json ] ; then
        echo "FATAL: download of TTN configuration failed"
        exit 1
else
        # Prepare configuration file
        node /opt/lora/merge.js $conf_dir/ttn_global_conf.json $conf_dir/multitech_overrides.json $conf_dir/global_conf.json
fi
 
