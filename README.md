# multitech-installer
Installer for TheThingsNetwork on MultiTech Conduit

Installation procedure:

1. Install LORA mCard as per instructions provided by MultiTech at
<http://www.multitech.net/developer/products/accessory-cards/installing-an-accessory-card/>.

2. Choose a computer (Windows, Linux, Mac) to use for configuring the Conduit. We'll call
this second computer the **host computer**. The host computer *must* have an Ethernet adapter.

3. Download `installer.sh` to the host computer (possibly
by using `git clone` to grab a copy of the repository). 

4. Connect the host computer to Conduit using an Ethernet cable, following the instructions at item 2 of
<http://www.multitech.net/developer/software/mlinux/getting-started-with-conduit-mlinux/>.

 You'll need to reconfigure an Ethernet adapter on your host computer so 
that it can connect to 192.168.2.0/24 -- this usually means either adding a
separate USB-to-Ethernet adapter to your computer, or temporarily reconfiguring
your primary Ethernet adapter. If you do the latter, you'll be disconnected
from your main network, and you need to write down your settings before you 
change anything. At this point, you definitely do *not* want to connect the Conduit
to your network directly.

 Configuring a static IP address on the host computer's Ethernet interface is a big topic in itself. If you
don't know how to do this, please contact your local The Things Netowrk community for
assistance, as you don't want to be doing this on your own.

 However, since the Conduit is 192.168.2.1 by default, we recommend the following settings on the host computer:

 Item|Setting
 ----|-------
 Address|192.168.2.2
 Netmask|255.255.255.0
 DNS server|none
 Gateway|none

 If you're setting up a lot of Conduits, using your everyday PC, you may find it helpful to purchase a cheap
USB-to-Ethernet adapter. Then you can just plug in the adapter whenever you're configuring a Conduit, and leave
the adapter always pre-configured. That way, you won't interfere with your normal settings.

 Of course, if you usualy use Wi-Fi to connect to the Internet, and you don't use the Ethernet adapter that's built
into your host computer, you might just want to dedicate that adapter to this purpose.  

5. Copy `installer.sh` to the Conduit using Putty SCP (on Windows, `pscp.exe`) or `scp` (Cygwin, Linux or macOS).

  `host-machine $ `**`scp installer.sh root@192.168.2.1:`**

6. Log into the Conduit from your host computer using ssh, and then run the installer. The following example assumes
you're using ssh.

  `host-machine $ `**`ssh root@192.168.2.1`**  
  `Password: `_root_ _(note that "root" won't be echoed)_  
  `Last login: Sun Aug  7 15:37:13 2016 from 192.168.2.2`  
  `root@mtcdt:~# `**`sh installer.sh`**

6. Provide answers to the prompts.  

 Be prepared -- if you have to disconnect your main system from the network, and you want to run a password-generation
 program, do so before starting the script.

   For the network you will need to choose a network with unrestricted access to the
   Internet. However, do not connect the Conduit directly (without firewall) to
   the Internet to prevent possible security issues!

   After the network settings have been provided, the Conduit shuts down. 

 Note that the script says "the gateway wil now shutdown", but you need to press "enter" in order to 
 get the gateway to continue into the shutdown process.  Here's an example:

 `The gateway will now shutdown. Remove power once the status led`   
 `stopped blinking, connect the gateway to the new network and reapply`  
 `power.`  

 `Press enter to continue`  
 _(press enter)_

 `Broadcast message from root@mtcdt (pts/0) (Sun Aug  7 17:08:03 2016):`  
  
 `The system is going down for system halt NOW!`  
 `Connection to 192.168.2.1 closed by remote host.`  
 `Connection to 192.168.2.1 closed.`  
 `-bash:myhost::/cygdrive/c/multitech-installer $ `

7. Once the
   LEDs on the front of the Conduit stop flashing, power the Conduit down and
   connect it to the target network. At the same time, **restore the network settings on your
   host computer** (if you changed them away from the default during step 4).

8. Log on to the Conduit using putty/ssh with the IP address information provided in
   step 6 or the IP address assigned to it by the DHCP server (when using DHCP)

9. Restart the installer to continue installation.

    `root@mtcdt:~# `**`sh installer.sh`**

 There may be a three or four-second pause while the installer is setting the time. Then you'll see:

  `7 Aug 17:18:27 ntpdate[519]: step time server 195.50.171.101 offset -393.789308 sec`  
  `SETUP FREQUENCY PLAN`  
  `Please select the configuration:`  
  `1) EU868`  
  `2) AU915`  
  `3) US915`  

 Answer the questions at each prompt, and the installer will configure your Conduit as needed.

10. When you're prompted for latitude and longitude, your best bet is to go to Google Maps. If you click on the location
 of your gateway, you'll see the latitude and longitude in a box at the bottom of the screen.

11. When you're prompted for the altitude, you should enter it in meters. (This is what's conventionally called the 
 "elevation" in mapping applications.) As of this writing, http://www.mapdevelopers.com/elevation_calculator.php 
 had a simple UI: enter the address and you get back the elevation, plus a map that you can click on for further 
 refinement. The elevation given by mapping apps is at ground level; if your gateway is substantially above ground i
 level, you may want to increase the number. 

Once the installer finishes (without errors), the Conduit has been connected to The Things Network.
