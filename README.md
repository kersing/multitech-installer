# multitech-installer
Installer for TheThingsNetwork on MultiTech Conduit

For detailed instructions see https://www.thethingsnetwork.org/labs/story/configure-your-multitech-aep-conduit-for-the-things-network (AEP model) or https://www.thethingsnetwork.org/labs/story/configure-your-multitech-mlinux-conduit-for-the-things-network (mLinux model)

Installation procedure:
1) Install LORA mCard as per instructions provided by MultiTech at
http://www.multitech.net/developer/products/accessory-cards/installing-an-accessory-card/

2) Download installer.sh

3) Connect to Conduit using the instruction at item 2 of
http://www.multitech.net/developer/software/mlinux/getting-started-with-conduit-mlinux/

4) Copy installer.sh to the conduit using Putty SCP (pscp.exe) or scp.

scp installer.sh root@192.168.2.1:

5) Using the connection established in step 3, run the installer.

sh installer.sh

6) Provide answers to the prompts.
   For the network you will need to choose a network with unrestricted access to the
   Internet. However, do not connect the Conduit directly (without firewall) to
   the Internet to prevent possible security issues!

   After the network settings have been provided the Conduit shuts down, once the
   leds on the front of the conduit stopped flashing, power the conduit down and
   connect it to the target network.

7) Log on to the Conduit using putty/ssh with the IP address information provided in
   step 6 or the IP address assigned to it by the DHCP server (when using DHCP)

8) Restart the installer to continue installation.

sh installer.sh

Once the installer finished (without errors) the Conduit is connected to TheThingsNetwork.
