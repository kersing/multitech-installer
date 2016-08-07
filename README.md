# multitech-installer
Installer for TheThingsNetwork on MultiTech Conduit

Installation procedure:

1. Install LORA mCard as per instructions provided by MultiTech at
http://www.multitech.net/developer/products/accessory-cards/installing-an-accessory-card/

2. Download installer.sh

3. Connect to Conduit using the instruction at item 2 of
[http://www.multitech.net/developer/software/mlinux/getting-started-with-conduit-mlinux/].
For this, you need a second computer. (It could be the one you're using to read this!)  
We'll call that the *host computer*. You'll need to clone this repository to the host computer, 
and then connect the host computer to the Conduit using the Ethernet cable. A
cable should have been included with your Conduit.

 You'll need to reconfigure an Ethernet adapter on your host computer so that
that it can connect to 192.168.2.0/24 -- this usually means either adding a
separate USB-to-Ethernet adapter to your computer, or temporarily reconfiguring
your primary Ethernet adapter. If you do the latter, you'll be disconnected
from your main network, and you need to write down your settings before you 
change anything. At this point, you definitely do *not* want to connect the Conduit
to your network directly.

 Configuring a static IP address on an interface is a big topic in itself. If you
don't know how to do this, please contact your local The Things Netowrk community for
assistance, as you don't want to be doing this on your own.

 However, since the Conduit is 192.168.2.1 by default, we recommend the following settings:

Item|Setting
----|-------
Address|192.168.2.2
Netmask|255.255.255.0
Gateway|none
DHCP|none

 If you're setting up a lot of Conduits, using your everyday PC, you may find it helpful to purchase a cheap
USB-to-Ethernet adapter. Then you can just plug in the adapter whenever you're configuring a Conduit, and leave
the adapter always pre-configured. That way, you won't interfere with your normal settings.

 Of course, if you usualy use Wi-Fi to connect to the Internet, and you don't use the Ethernet adapter that's built
into your host computer, you might just want to dedicate that adapter to this purpose.  

4. Copy installer.sh to the conduit using Putty SCP (pscp.exe) or scp.

    scp installer.sh root@192.168.2.1:

5. Using the connection established in step 3, run the installer.

    \# sh installer.sh

6. Provide answers to the prompts.
   For the network you will need to choose a network with unrestricted access to the
   Internet. However, do not connect the Conduit directly (without firewall) to
   the Internet to prevent possible security issues!

   After the network settings have been provided the Conduit shuts down. Once the
   LEDs on the front of the Conduit stop flashing, power the Conduit down and
   connect it to the target network.

7. Log on to the Conduit using putty/ssh with the IP address information provided in
   step 6 or the IP address assigned to it by the DHCP server (when using DHCP)

8. Restart the installer to continue installation.

    \# sh installer.sh

 Once the installer finishes (without errors) the Conduit is connected to The Things Network.
