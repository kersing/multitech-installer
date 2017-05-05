#!/bin/bash
#
# Script to install packages for TTN on MultiTech Linux Conduit
# 
# Written by Jac Kersing <j.kersing@the-box.com>
#
# Parts of the script based on tzselect by Paul Eggert.
#

STATUSFILE=/var/config/.installer
VERSION=3.0.0-r1
FILENAME=mp-packet-forwarder_${VERSION}_arm926ejste.ipk
URL=https://raw.github.com/kersing/multitech-installer/master/${FILENAME}

grep package $STATUSFILE > /dev/null 2> /dev/null
if [ $? -eq 0 ]
	if [ ! -x /opt/lora/mp_pkt_fwd -a ! -x /opt/lora/poly_pkt_fwd ] ; then
		# statusfile not reset, but gateway has been reflashed, clear file
		rm $STATUSFILE
		# and remove software to force re-install
		opkg remove poly-packet-forwarder > dev/null 2>&1
		opkg remove mp-packet-forwarder > dev/null 2>&1
	fi
fi

if [ ! -f $STATUSFILE ] ; then
	touch $STATUSFILE
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

# check for AEP model and ask user to skip network/timezone setup
# /var/config/db.json is only present on AEP models, use it to detect AEP
grep network $STATUSFILE > /dev/null 2> /dev/null
if [ $? -ne 0 -a -f /var/config/db.json ] ; then
	# Securing the device should be done using the web interface
	echo "secure" >> $STATUSFILE
	echo "AEP Model detected, have time zone and network been setup?"
	doselect Yes No
	if [ "$select_result" = "No" ] ; then
		echo "Please configure \"network interfaces\" and \"time\" using the web interface and restart."
		echo "DO NOT configure \"LoRa Network Server\" in the web interface!"
		exit
	fi
	echo "timezone" >> $STATUSFILE
	echo "network" >> $STATUSFILE
fi

grep secure $STATUSFILE > /dev/null 2> /dev/null
if [ $? -ne 0 ] ; then
	# Start by securing the device
	echo "Securing access to the device, enter the same password twice and"
	echo "make sure to save this password as the device requires factory"
	echo "reset when the password is lost!!"
	passwd root
	echo "secure" >> $STATUSFILE
fi

grep timezone $STATUSFILE > /dev/null 2> /dev/null
if [ $? -ne 0 ] ; then
	# -------------------------------- from tzselect code: --------------------
	# Interact with the user via stderr and stdin.
	# Contributed by Paul Eggert.  This file is in the public domain.

	# Specify default values for environment variables if they are unset.
	AWK=awk
	TZDIR=/usr/share/zoneinfo

	coord=
	location_limit=10
	zonetabtype=zone

	# Make sure the tables are readable.
	TZ_COUNTRY_TABLE=$TZDIR/iso3166.tab
	TZ_ZONE_TABLE=$TZDIR/$zonetabtype.tab
	for f in $TZ_COUNTRY_TABLE $TZ_ZONE_TABLE
	do
		<"$f" || {
			say >&2 "$0: time zone files are not set up correctly"
			exit 1
		}
	done

	# If the current locale does not support UTF-8, convert data to current
	# locale's format if possible, as the shell aligns columns better that way.
	# Check the UTF-8 of U+12345 CUNEIFORM SIGN URU TIMES KI.
	! $AWK 'BEGIN { u12345 = "\360\222\215\205"; exit length(u12345) != 1 }' &&
	    { tmp=`(mktemp -d) 2>/dev/null` || {
		tmp=${TMPDIR-/tmp}/tzselect.$$ &&
		(umask 77 && mkdir -- "$tmp")
	    };} &&
	    trap 'status=$?; rm -fr -- "$tmp"; exit $status' 0 HUP INT PIPE TERM &&
	    (iconv -f UTF-8 -t //TRANSLIT <"$TZ_COUNTRY_TABLE" >$tmp/iso3166.tab) \
		2>/dev/null &&
	    TZ_COUNTRY_TABLE=$tmp/iso3166.tab &&
	    iconv -f UTF-8 -t //TRANSLIT <"$TZ_ZONE_TABLE" >$tmp/$zonetabtype.tab &&
	    TZ_ZONE_TABLE=$tmp/$zonetabtype.tab

newline='
'
	IFS=$newline


	# Awk script to read a time zone table and output the same table,
	# with each column preceded by its distance from 'here'.
	output_distances='
	  BEGIN {
	    FS = "\t"
	    while (getline <TZ_COUNTRY_TABLE)
	      if ($0 ~ /^[^#]/)
		country[$1] = $2
	    country["US"] = "US" # Otherwise the strings get too long.
	  }
	  function abs(x) {
	    return x < 0 ? -x : x;
	  }
	  function min(x, y) {
	    return x < y ? x : y;
	  }
	  function convert_coord(coord, deg, minute, ilen, sign, sec) {
	    if (coord ~ /^[-+]?[0-9]?[0-9][0-9][0-9][0-9][0-9][0-9]([^0-9]|$)/) {
	      degminsec = coord
	      intdeg = degminsec < 0 ? -int(-degminsec / 10000) : int(degminsec / 10000)
	      minsec = degminsec - intdeg * 10000
	      intmin = minsec < 0 ? -int(-minsec / 100) : int(minsec / 100)
	      sec = minsec - intmin * 100
	      deg = (intdeg * 3600 + intmin * 60 + sec) / 3600
	    } else if (coord ~ /^[-+]?[0-9]?[0-9][0-9][0-9][0-9]([^0-9]|$)/) {
	      degmin = coord
	      intdeg = degmin < 0 ? -int(-degmin / 100) : int(degmin / 100)
	      minute = degmin - intdeg * 100
	      deg = (intdeg * 60 + minute) / 60
	    } else
	      deg = coord
	    return deg * 0.017453292519943296
	  }
	  function convert_latitude(coord) {
	    match(coord, /..*[-+]/)
	    return convert_coord(substr(coord, 1, RLENGTH - 1))
	  }
	  function convert_longitude(coord) {
	    match(coord, /..*[-+]/)
	    return convert_coord(substr(coord, RLENGTH))
	  }
	  # Great-circle distance between points with given latitude and longitude.
	  # Inputs and output are in radians.  This uses the great-circle special
	  # case of the Vicenty formula for distances on ellipsoids.
	  function gcdist(lat1, long1, lat2, long2, dlong, x, y, num, denom) {
	    dlong = long2 - long1
	    x = cos(lat2) * sin(dlong)
	    y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dlong)
	    num = sqrt(x * x + y * y)
	    denom = sin(lat1) * sin(lat2) + cos(lat1) * cos(lat2) * cos(dlong)
	    return atan2(num, denom)
	  }
	  # Parallel distance between points with given latitude and longitude.
	  # This is the product of the longitude difference and the cosine
	  # of the latitude of the point that is further from the equator.
	  # I.e., it considers longitudes to be further apart if they are
	  # nearer the equator.
	  function pardist(lat1, long1, lat2, long2) {
	    return abs(long1 - long2) * min(cos(lat1), cos(lat2))
	  }
	  # The distance function is the sum of the great-circle distance and
	  # the parallel distance.  It could be weighted.
	  function dist(lat1, long1, lat2, long2) {
	    return gcdist(lat1, long1, lat2, long2) + pardist(lat1, long1, lat2, long2)
	  }
	  BEGIN {
	    coord_lat = convert_latitude(coord)
	    coord_long = convert_longitude(coord)
	  }
	  /^[^#]/ {
	    here_lat = convert_latitude($2)
	    here_long = convert_longitude($2)
	    line = $1 "\t" $2 "\t" $3
	    sep = "\t"
	    ncc = split($1, cc, /,/)
	    for (i = 1; i <= ncc; i++) {
	      line = line sep country[cc[i]]
	      sep = ", "
	    }
	    if (NF == 4)
	      line = line " - " $4
	    printf "%g\t%s\n", dist(coord_lat, coord_long, here_lat, here_long), line
	  }
	'

	# Begin the main loop.  We come back here if the user wants to retry.
	while

		echo >&2 'Please identify a location' \
			'so that time zone rules can be set correctly.'

		continent=
		country=
		region=

		case $coord in
		?*)
			continent=coord;;
		'')

		# Ask the user for continent or ocean.

		echo >&2 'Please select a continent, ocean, "coord", or "TZ".'

		quoted_continents=`
		  $AWK '
		    BEGIN { FS = "\t" }
		    /^[^#]/ {
		      entry = substr($3, 1, index($3, "/") - 1)
		      if (entry == "America")
			entry = entry "s"
		      if (entry ~ /^(Arctic|Atlantic|Indian|Pacific)$/)
			entry = entry " Ocean"
		      printf "'\''%s'\''\n", entry
		    }
		  ' <"$TZ_ZONE_TABLE" |
		  sort -u |
		  tr '\n' ' '
		  echo ''
		`

		eval '
		    doselect '"$quoted_continents"' \
			"coord - I want to use geographical coordinates." \
			"TZ - I want to specify the time zone using the Posix TZ format."
		    continent=$select_result
		    case $continent in
		    Americas) continent=America;;
		    *" "*) continent=`expr "$continent" : '\''\([^ ]*\)'\''`
		    esac
		'
		esac

		case $continent in
		TZ)
			# Ask the user for a Posix TZ string.  Check that it conforms.
			while
				echo >&2 'Please enter the desired value' \
					'of the TZ environment variable.'
				echo >&2 'For example, GST-10 is a zone named GST' \
					'that is 10 hours ahead (east) of UTC.'
				read TZ
				$AWK -v TZ="$TZ" 'BEGIN {
					tzname = "(<[[:alnum:]+-]{3,}>|[[:alpha:]]{3,})"
					time = "(2[0-4]|[0-1]?[0-9])" \
					  "(:[0-5][0-9](:[0-5][0-9])?)?"
					offset = "[-+]?" time
					mdate = "M([1-9]|1[0-2])\\.[1-5]\\.[0-6]"
					jdate = "((J[1-9]|[0-9]|J?[1-9][0-9]" \
					  "|J?[1-2][0-9][0-9])|J?3[0-5][0-9]|J?36[0-5])"
					datetime = ",(" mdate "|" jdate ")(/" time ")?"
					tzpattern = "^(:.*|" tzname offset "(" tzname \
					  "(" offset ")?(" datetime datetime ")?)?)$"
					if (TZ ~ tzpattern) exit 1
					exit 0
				}'
			do
			    say >&2 "'$TZ' is not a conforming Posix time zone string."
			done
			TZ_for_date=$TZ;;
		*)
			case $continent in
			coord)
			    case $coord in
			    '')
				echo >&2 'Please enter coordinates' \
					'in ISO 6709 notation.'
				echo >&2 'For example, +4042-07403 stands for'
				echo >&2 '40 degrees 42 minutes north,' \
					'74 degrees 3 minutes west.'
				read coord;;
			    esac
			    distance_table=`$AWK \
				    -v coord="$coord" \
				    -v TZ_COUNTRY_TABLE="$TZ_COUNTRY_TABLE" \
				    "$output_distances" <"$TZ_ZONE_TABLE" |
			      sort -n |
			      sed "${location_limit}q"
			    `
			    regions=`say "$distance_table" | $AWK '
			      BEGIN { FS = "\t" }
			      { print $NF }
			    '`
			    echo >&2 'Please select one of the following' \
				    'time zone regions,'
			    echo >&2 'listed roughly in increasing order' \
				    "of distance from $coord".
			    doselect $regions
			    region=$select_result
			    TZ=`say "$distance_table" | $AWK -v region="$region" '
			      BEGIN { FS="\t" }
			      $NF == region { print $4 }
			    '`
			    ;;
			*)
			# Get list of names of countries in the continent or ocean.
			countries=`$AWK \
				-v continent="$continent" \
				-v TZ_COUNTRY_TABLE="$TZ_COUNTRY_TABLE" \
			'
				BEGIN { FS = "\t" }
				/^#/ { next }
				$3 ~ ("^" continent "/") {
				    ncc = split($1, cc, /,/)
				    for (i = 1; i <= ncc; i++)
					if (!cc_seen[cc[i]]++) cc_list[++ccs] = cc[i]
				}
				END {
					while (getline <TZ_COUNTRY_TABLE) {
						if ($0 !~ /^#/) cc_name[$1] = $2
					}
					for (i = 1; i <= ccs; i++) {
						country = cc_list[i]
						if (cc_name[country]) {
						  country = cc_name[country]
						}
						print country
					}
				}
			' <"$TZ_ZONE_TABLE" | sort -f`


			# If there's more than one country, ask the user which one.
			case $countries in
			*"$newline"*)
				echo >&2 'Please select a country' \
					'whose clocks agree with yours.'
				doselect $countries
				country=$select_result;;
			*)
				country=$countries
			esac


			# Get list of names of time zone rule regions in the country.
			regions=`$AWK \
				-v country="$country" \
				-v TZ_COUNTRY_TABLE="$TZ_COUNTRY_TABLE" \
			'
				BEGIN {
					FS = "\t"
					cc = country
					while (getline <TZ_COUNTRY_TABLE) {
						if ($0 !~ /^#/  &&  country == $2) {
							cc = $1
							break
						}
					}
				}
				/^#/ { next }
				$1 ~ cc { print $4 }
			' <"$TZ_ZONE_TABLE"`


			# If there's more than one region, ask the user which one.
			case $regions in
			*"$newline"*)
				echo >&2 'Please select one of the following' \
					'time zone regions.'
				doselect $regions
				region=$select_result;;
			*)
				region=$regions
			esac

			# Determine TZ from country and region.
			TZ=`$AWK \
				-v country="$country" \
				-v region="$region" \
				-v TZ_COUNTRY_TABLE="$TZ_COUNTRY_TABLE" \
			'
				BEGIN {
					FS = "\t"
					cc = country
					while (getline <TZ_COUNTRY_TABLE) {
						if ($0 !~ /^#/  &&  country == $2) {
							cc = $1
							break
						}
					}
				}
				/^#/ { next }
				$1 ~ cc && $4 == region { print $3 }
			' <"$TZ_ZONE_TABLE"`
			esac

			# Make sure the corresponding zoneinfo file exists.
			TZ_for_date=$TZDIR/$TZ
			<"$TZ_for_date" || {
				say >&2 "$0: time zone files are not set up correctly"
				exit 1
			}
		esac

		# Output TZ info and ask the user to confirm.

		echo >&2 ""
		echo >&2 "The following information has been given:"
		echo >&2 ""
		case $country%$region%$coord in
		?*%?*%)	say >&2 "	$country$newline	$region";;
		?*%%)	say >&2 "	$country";;
		%?*%?*) say >&2 "	coord $coord$newline	$region";;
		%%?*)	say >&2 "	coord $coord";;
		*)	say >&2 "	TZ='$TZ'"
		esac
		say >&2 ""
		say >&2 "Therefore TZ='$TZ' will be used."
		say >&2 "Is the above information OK?"

		doselect Yes No
		ok=$select_result
		case $ok in
		Yes) break
		esac
	do coord=
	done

	# -------------------------------- end tzselect --------------------

	# link choosen timezone
	ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
	echo "timezone" >> $STATUSFILE
fi

# On to the network information
grep network $STATUSFILE > /dev/null 2> /dev/null
if [ $? -ne 0 ] ; then
	echo ""
	echo "NETWORK SETUP"
	echo ""
	echo "Do you want to use DHCP"
	doselect Yes No
	ok=$select_result
	case $ok in
		Yes)
			if [ ! -f /var/config/network/interfaces.org ] ; then
				mv /var/config/network/interfaces /etc/network/interfaces.org
			fi
			cat << _EOF_ > /var/config/network/interfaces
# /etc/network/interfaces -- configuration file for ifup(8), ifdown(8)

# The loopback interface
auto lo
iface lo inet loopback

# Wired interface
auto eth0
iface eth0 inet dhcp
#iface eth0 inet static
#address 192.168.2.1
#netmask 255.255.255.0
#gateway 192.168.2.254

# Bridge interface with eth0 (comment out eth0 lines above to use with bridge)
# iface eth0 inet manual
#
# auto br0
# iface br0 inet static
# bridge_ports eth0
# address 192.168.2.1
# netmask 255.255.255.0

# Wifi client
# NOTE: udev rules will bring up wlan0 automatically if a wifi device is detected
# and the wlan0 interface is defined, therefore an "auto wlan0" line is not needed.
# If "auto wlan0" is also specified, startup conflicts may result.
#iface wlan0 inet dhcp
#wpa-conf /var/config/wpa_supplicant.conf
#wpa-driver nl80211
_EOF_
			;;
		No)
			got_it=No
			while [ $got_it != Yes ] ; do
				echo "Please provide network parameters"
				echo -n "IP address: "
				read ip
				echo -n "netmask: "
				read mask
				echo -n "gateway: "
				read gw
				echo -n "DNS IP (use 8.8.8.8 for Google DNS): "
				read dns
				echo
				echo "Supplied information:"
				echo "IP     : $ip"
				echo "Netmask: $mask"
				echo "Gateway: $gw"
				echo "DNS IP : $dns"		
				doselect Yes No
				got_it=$select_result
			done
			cat << _EOF_ > /var/config/network/interfaces
# /etc/network/interfaces -- configuration file for ifup(8), ifdown(8)

# The loopback interface
auto lo
iface lo inet loopback

# Wired interface
auto eth0
iface eth0 inet static
address $ip
netmask $mask
gateway $gw
post-up echo 'nameserver $dns' >/etc/resolv.conf

# Bridge interface with eth0 (comment out eth0 lines above to use with bridge)
# iface eth0 inet manual
#
# auto br0
# iface br0 inet static
# bridge_ports eth0
# address 192.168.2.1
# netmask 255.255.255.0

# Wifi client
# NOTE: udev rules will bring up wlan0 automatically if a wifi device is detected
# and the wlan0 interface is defined, therefore an "auto wlan0" line is not needed.
# If "auto wlan0" is also specified, startup conflicts may result.
#iface wlan0 inet dhcp
#wpa-conf /var/config/wpa_supplicant.conf
#wpa-driver nl80211
_EOF_
	esac
			
	echo "network" >> $STATUSFILE
	echo "Network configuration written"
	echo ""
	echo "The gateway will now shutdown. Remove power once the status led"
	echo "stopped blinking, connect the gateway to the new network and reapply"
	echo "power."
	echo ""
	echo "Press enter to continue"
	read n
	sync;sync;sync
	shutdown -h now
	sleep 600
fi

# Network should be configured allowing access to remote servers at this point
#
wget http://www.thethingsnetwork.org/ --no-check-certificate -O /dev/null -o /dev/null
if [ $? -ne 0 ] ; then
	echo "Error in network settings, cannot access www.thethingsnetwork.org"
	echo "Check network settings and rerun this script to correct the setup"
	grep -v network $STATUSFILE > $STATUSFILE.tmp
	mv $STATUSFILE.tmp $STATUSFILE
	exit 1
fi

# Set date and time using ntpdate
grep date $STATUSFILE > /dev/null 2> /dev/null
if [ $? -ne 0 ] ; then
	ntpdate 0.europe.pool.ntp.org
	hwclock -u -w
	echo "date" >> $STATUSFILE
fi

if [ ! -d /var/config/lora ] ; then
	mkdir /var/config/lora
fi	

# Ask for location/configuration
grep location $STATUSFILE > /dev/null 2> /dev/null
if [ $? -ne 0 ] ; then
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
if [ $? -ne 0 ] ; then
	got_it="No"
	while [ "$got_it" != "Yes" ] ; do
		echo "SETUP LORA GATEWAY CONFIGURATION"
		echo -n "E-mail address of gateway operator: "
		read email
		echo -n "Gateway description: "
		read descr
		echo "Include location information?"
		echo "NOTE: No location information means the gateway status information will not be available on-line"
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
{
/* Settings defined in global_conf will be overwritten by those in local_conf */
    "gateway_conf": {
        /* gateway_ID is based on unique hardware ID, do not edit */
        "gateway_ID": "$gwid",
        /* Email of gateway operator, max 40 chars*/
        "contact_email": "$email", 
        /* Public description of this device, max 64 chars */
        "description": "$descr",
        /* Enter VALID GPS coordinates below before enabling fake GPS */
_EOF_
        if [ X"$lat" != X"0" -o X"$lon" != X"0" ] ; then
        cat << _EOF_ >> /var/config/lora/local_conf.json
        "gps": true,
        "fake_gps": true,
        "ref_latitude": $lat,
        "ref_longitude": $lon,
        "ref_altitude": $alt
_EOF_
        else
        cat << _EOF_ >> /var/config/lora/local_conf.json
        "gps": false,
        "fake_gps": false
_EOF_
        fi
        cat << _EOF_ >> /var/config/lora/local_conf.json
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
	/etc/init.d/lora-packet-forwarder stop
	cat << _EOF_ > /etc/default/lora-network-server
# set to "yes" or "no" to control starting on boot
ENABLED="no"
_EOF_
	if [ -f /etc/default/lora-packet-forwarder ] ; then
		cat << _EOF_ > /etc/default/lora-packet-forwarder
# set to "yes" or "no" to control starting on boot
ENABLED="no"
_EOF_
	fi
	update-rc.d -f lora-network-server remove > /dev/null 2> /dev/null
	if [ -f /etc/init.d/lora-packet-forwarder ] ; then
		update-rc.d -f lora-packet-forwarder remove > /dev/null 2> /dev/null
	fi
	echo "disable-mtech" >> $STATUSFILE
fi

# Check for previous forwarder
opkg list-installed poly-packet-forwarder | grep poly-packet-forwarder > /dev/null 2> /dev/null
if [ $? -eq 0 ] ; then
	echo "Removing obsolete poly forwarder"
	opkg remove poly-packet-forwarder
fi

grep mp-package $STATUSFILE > /dev/null 2> /dev/null
if [ $? -ne 0 ] ; then
	fnd=$(opkg list-installed poly-packet-forwarder)
	version=$(echo $fnd | cut -d' ' -f 3)
	if [ X"$version" != X"$VERSION" ] ; then
		echo "Installing TTN Multi Protocol Packet Forwarder"
		wget $URL -O /tmp/$FILENAME -o /dev/null --no-check-certificate
		opkg install /tmp/$FILENAME
	fi
	echo "mp-package" >> $STATUSFILE
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
	node /opt/lora/merge.js /var/config/lora/ttn_global_conf.json /var/config/lora/multitech_overrides.json /var/config/lora/global_conf.json
fi

# Everything is in place, start forwarder
/etc/init.d/ttn-pkt-forwarder start

echo "The installation is now complete. Please register your gateway"
echo "at The Things Network ( https://www.thethingsnetwork.org ,"
echo "click on 'Hi <your name>' at the right of the menu bar, select"
echo "'My Profile', scroll down to select 'Add Gateway') using"
echo "gateway ID: $gwid"
