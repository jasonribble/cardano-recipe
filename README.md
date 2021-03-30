# Cardano Recipe

## Requirements

## Step 1a. Start block producer server

Go to Digital Ocean. We are creating 2 droplets, one relay, one block producer. We will first start creating the block producer.

OS: Ubuntun 20.04 (LTS) x64
- Block Producer
  - 8GB RAM

Once the nodes are stared, update the server

## Step 1b. Harden server

### Add user

SSH in to the server

Add a new user with a unique password. We suggest using a password manager to generate a strong password.

```
adduser cardano
```

Add SSH keys to user .ssh file. This allows to use the same keys added via Digital Ocean

```
rsync --archive --chown=cardano:cardano ~/.ssh /home/cardano
```

### SSH Hardening 

Log out and test the new user. Then, disable root login and password based login. Edit the `/etc/ssh/sshd_config` file and locate the following and make sure they have the following values (they are should be no). Additionally, set the port.

```
ChallengeResponseAuthentication no
...
PasswordAuthentication no 
...
PermitRootLogin no
...
PermitEmptyPasswords no
...
Port $YOUR_PORT_NUMBER
```

Valaidate the syntax of your new SSH config.

```
sudo sshd -t
```

If no errors with the syntax validation, reload the SSH process

```
sudo service sshd reload
```

Upload your port in your config or alias. Or add `ssh -p $YOUR_PORT_NUM` to your ssh command 


### Update the system

It's important to have the latest packages. Before doing so, start a tmux session; in case the internet goes out or you want to get a coffee without baby-sitting a terminal.
```
tmux new -s ada 
```

```
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get autoremove
sudo apt-get autoclean
```

Enable automatic updates so you don't have to manually install them.
```
sudo apt-get install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

Install useful things
```
sudo apt-get install net-tools tree
```

Disable root:

```
# To disable the root account, simply use the -l option.
sudo passwd -l root
```
```
# If for some valid reason you need to re-enable the account, simply use the -u option.
sudo passwd -u root
```

### Secure Shared Memory
Edit `/etc/fstab`

Insert the following line to the bottom of the file and save/close:

```
tmpfs	/run/shm	tmpfs	ro,noexec,nosuid	0 0
```

Reboot the node in order for changes to take effect.

```
sudo reboot
```

### Install Fail2ban

```
sudo apt-get install fail2ban -y
```

Edit a config file that monitors SSH logins.

```
sudo vim /etc/fail2ban/jail.local
```

Add the following
```
[sshd]
enabled = true
port = INSERT_YOUR_SSH_PORT_NUMBER_HERE
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
# whitelisted IP addresses. For instance, a single IP address from a VPN end point.
# ignoreip = INSERT_A_SAFE_IP_HERE_IF_DESIRED
```

For ignoreip, if there is a specific IP address that is used, remove the # (comment) and space and add the IP address after the equals. For example

```
ignoreip = 127.0.0.1
```

Enbale and Restart fail2ban for setting to take effect

```
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
```

### Configure Firewall

The standard UFW firewall can be used to control network access to your node.
With any new installation, ufw is disabled by default. Enable it with the following settings.
- Port 22 (or your random port #) TCP for SSH connection
- Port 600 (or your random p2p port #) TCP for p2p traffic


A) *Run this on your Block Producer only:*
Only your Relay Node(s) should be permitted access to your Block Producer Node.


```
ufw allow <22 or your random port number>/tcp
ufw enable
ufw status numbered
```

```
sudo ufw allow proto tcp from <RELAY NODE IP> to any port <BLOCK PRODUCER PORT>
# Example
# sudo ufw allow proto tcp from 18.58.3.31 to any port 6000
```

B) *Run this on your Relay(s) only:*


```
ufw allow <22 or your random port number>/tcp
ufw allow <6000 or your random p2p port number>/tcp
ufw enable
ufw status numbered
```

In order to protect your Relay Node(s) from a novel "DoS/Syn" attack, Michael Fazio created iptables entry which restricts connections to a given destination port to 5 connections from the same IP. 

Replace <RELAY NODE PORT> with your public relay port. Opitonally, you can replace the 5 with your preferred connection limit.

```
iptables -I INPUT -p tcp -m tcp --dport <RELAY NODE PORT> --tcp-flags FIN,SYN,RST,ACK SYN -m connlimit --connlimit-above 5 --connlimit-mask 32 --connlimit-saddr -j REJECT --reject-with tcp-reset
```

#### Verify Listening Ports

If you want to maintain a secure server, you should validate the listening network ports every once in a while. This will provide you essential information about your network.

```
netstat -tulpn
```

```
ss -tulpn
```

We will open up ports for monitoring at a later time:

- Port 3000 TCP for Grafana web server (if hosted on current node)
- Port 9090 tcp for Prometheus export data (optional, if hosted on current node)

## Step 1b + 2b. Create Relay server

Follow the same steps as step 1a and 2a, except with a relay server. 

The only difference will be when setting up the firewall.

## Step 3a: Get the Prereqs (with CNTools) 
On both servers, run the prereqs scripts provided by CNTools. Make sure you have a tmux session 

```
tmux new -s cnode
```

```
mkdir "$HOME/tmp"
cd "$HOME/tmp"
# sudo apt -y install curl # run this is curl is not installed.
curl -sS -o prereqs.sh https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/prereqs.sh
chmod 755 prereqs.sh
./prereqs.sh
source "$HOME/.bashrc"
```

Check the `$HOME/.bashrc` file to make sure enviroment variables are set properly. You can echo it on the command line to confirm as well
```
echo $CNODE_HOME
```

## Step 3a: Install cardano-node (with CNTools) 

Once complete, we should have all the packages, we can build cardano-node, cardano-cli and more.

```
git fetch --tags --all
# Replace tag against checkout if you do not want to build the latest released version
git pull
git checkout $(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | jq -r .tag_name)

# The "-o" flag against script below will download cabal.project.local to depend on system libSodium package, and include cardano-address and bech32 binaries to your build
$CNODE_HOME/scripts/cabal-build-all.sh -o
```

Confirm it built

```
cardano-cli version
# cardano-cli 1.25.1 - linux-x86_64 - ghc-8.10
# git rev 9a7331cce5e8bc0ea9c6bfa1c28773f4c5a7000f
cardano-node version
# cardano-node 1.25.1 - linux-x86_64 - ghc-8.10
# git rev 9a7331cce5e8bc0ea9c6bfa1c28773f4c5a7000f
```

In this tutorial, since we are importing the wallets, we want to confirm that bech32 and cardano-address are available in the proper path:

```
ls -l ~/.cabal/bin
```

If it is not there, remove the cardano-node repo and repeat step 3b:

```
cd ~/git
rm -rf cardano-node
```

Before you go ahead with starting your node, you may want to update values for CNODE_PORT in $CNODE_HOME/scripts/env. Note that it is imperative for operational relays and pools to ensure that the port mentioned is opened via firewall to the destination your node is supposed to connect from. Update your network/firewall configuration accordingly. Future executions of prereqs.sh will preserve and not overwrite these values.

```
CNODE_PORT=6000
POOL_NAME="GUILD"
```

*POOL_NAME is the name of folder that you will use when registering pools and starting node in core mode. This folder would typically contain your hot.skey,vrf.skey and op.cert files required. If the mentioned files are absent, the node will automatically start in a passive mode.*

Deploy as a systemd service

```
cd $CNODE_HOME/scripts
./deploy-as-systemd.sh
```

*IMPORTANT to know when you run ./deploy-as-systemd.sh:*
It will ask also to set the topologyupdater process as systemd and you will:

- Producer: press NO for topologyUpdater
- Relay: press YES for topologyUpdater, let the default timer for cnode auto restart to 86400


Start the servcie

```
sudo systemctl enable cnode.service
sudo systemctl start cnode.service
```

Check status 

```
sudo systemctl status cnode.service
```

Use gLiveView (Guild LiveView) to montior the pool that was started by systemd
```
cd $CNODE_HOME/scripts
./gLiveView
```

## Step 4: Modify Topology

### Producer
```
cd $CNODE_HOME/files
vim topology.json
```
Then, put the following
```
{
  "Producers": [
    {
      "addr": "RELAY_IP_ADDRESS",  
      "port": RELAY_PORT,  
      "valency": 1
    }
  ]
}
```

If you have more than one relay, it will look like this 

```
{
  "Producers": [
    {
      "addr": "RELAY1 IP ADDRESS",  
      "port": RELAY_PORT,  
      "valency": 1
    },
      {
      "addr": "RELAY2 IP ADDRESS",  
      "port": RELAY_PORT,  
      "valency": 1
    }
  ]
}
```

Make sure the firewall is set properly.
```
sudo ufw status
```

Reset the node and wait a cfew minutes and confirm Peer info in gLiveView

```
cd $CNODE_HOME/scripts
sudo systemctl restart cnode
sudo systemctl status cnode
./gLiveView.sh
```

Restart the node wait few minutes an check again with gliveview. The IP should appear in the Peers menu (press P)

### Relay

The relay will connect to the Producer and dynamically with other public replays

First, edit the topologyUpdate to add the CUSTOM_PEERS line to add the Producer's IP and port

```
CUSTOM_PEERS="INSERT_PRODUCER_IP:INSERT_PRODUCER_PORT" 
```
To add more, it would like like this 
```
CUSTOM_PEERS="1.1.1.1:6000" 
```

Add a rule in Relay FIREWALL to allow connections from all public Relay on port RELAY_PORT ( where RELAY_PORT is the CNODE PORT configured in env file)

```
sudo ufw allow proto tcp from any to any port RELAY_PORT
```

Restart the node wait few minutes an check again with gliveview. The IP should appear in the Peers menu (press P)

## Step 5: Create Pool Meta Data on Github.

Create a github gist with the meta data. Here's the general format 

```
{
  "name": "TestPool",
  "description": "The pool that tests all the pools",
  "ticker": "TEST",
  "homepage": "https://teststakepool.com"
}
```

It is suggested to have it all in one line without space before each property. Although preference, this makes share that some random space doesn't change the hash output. 

Once you have a RAW Url from Github, put it in [Git.io](https://git.io) to shortent it. Save the URL for later. For example: https://git.io/JYTZj



## Step 6: Create/Import wallet and Register the Pool

Following CNTools [Offline Work](https://cardano-community.github.io/guild-operators/#/Scripts/cntools?id=offline-workflow),, we will keep our keys save with a hybrid pool creation of our wallet(s) and 

<svg id="mermaid-svg-0" width="100%" xmlns="http://www.w3.org/2000/svg" height="884" style="max-width: 1389px;" viewBox="-316.5 -10 1389 884"><style>#mermaid-svg-0{font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:16px;fill:#000000;}#mermaid-svg-0 .error-icon{fill:#552222;}#mermaid-svg-0 .error-text{fill:#552222;stroke:#552222;}#mermaid-svg-0 .edge-thickness-normal{stroke-width:2px;}#mermaid-svg-0 .edge-thickness-thick{stroke-width:3.5px;}#mermaid-svg-0 .edge-pattern-solid{stroke-dasharray:0;}#mermaid-svg-0 .edge-pattern-dashed{stroke-dasharray:3;}#mermaid-svg-0 .edge-pattern-dotted{stroke-dasharray:2;}#mermaid-svg-0 .marker{fill:#42B983;stroke:#42B983;}#mermaid-svg-0 .marker.cross{stroke:#42B983;}#mermaid-svg-0 svg{font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:16px;}#mermaid-svg-0 .actor{stroke:hsl(78.1578947368,58.4615384615%,54.5098039216%);fill:#42B983;}#mermaid-svg-0 text.actor &gt; tspan{fill:black;stroke:none;}#mermaid-svg-0 .actor-line{stroke:#42B983;}#mermaid-svg-0 .messageLine0{stroke-width:1.5;stroke-dasharray:none;stroke:#42B983;}#mermaid-svg-0 .messageLine1{stroke-width:1.5;stroke-dasharray:2,2;stroke:#42B983;}#mermaid-svg-0 #arrowhead path{fill:#42B983;stroke:#42B983;}#mermaid-svg-0 .sequenceNumber{fill:white;}#mermaid-svg-0 #sequencenumber{fill:#42B983;}#mermaid-svg-0 #crosshead path{fill:#42B983;stroke:#42B983;}#mermaid-svg-0 .messageText{fill:#d22778;stroke:#d22778;}#mermaid-svg-0 .labelBox{stroke:#326932;fill:#cde498;}#mermaid-svg-0 .labelText,#mermaid-svg-0 .labelText &gt; tspan{fill:black;stroke:none;}#mermaid-svg-0 .loopText,#mermaid-svg-0 .loopText &gt; tspan{fill:#FFFFFF;stroke:none;}#mermaid-svg-0 .loopLine{stroke-width:2px;stroke-dasharray:2,2;stroke:#326932;fill:#326932;}#mermaid-svg-0 .note{stroke:#000000;fill:#fff5ad;}#mermaid-svg-0 .noteText,#mermaid-svg-0 .noteText &gt; tspan{fill:black;stroke:none;}#mermaid-svg-0 .activation0{fill:#f4f4f4;stroke:#666;}#mermaid-svg-0 .activation1{fill:#f4f4f4;stroke:#666;}#mermaid-svg-0 .activation2{fill:#f4f4f4;stroke:#666;}#mermaid-svg-0:root{--mermaid-font-family:"trebuchet ms",verdana,arial,sans-serif;}#mermaid-svg-0 sequence{fill:apa;}</style><g></g><g><line id="actor0" x1="75" y1="5" x2="75" y2="873" class="actor-line" stroke-width="0.5px" stroke="#999"></line><rect x="0" y="0" fill="#eaeaea" stroke="#666" width="150" height="65" rx="3" ry="3" class="actor"></rect><text x="75" y="32.5" style="text-anchor: middle; font-weight: 400; font-family: &quot;Open-Sans&quot;, &quot;sans-serif&quot;;" dominant-baseline="central" alignment-baseline="central" class="actor"><tspan x="75" dy="0">Offline</tspan></text></g><g><line id="actor1" x1="710" y1="5" x2="710" y2="873" class="actor-line" stroke-width="0.5px" stroke="#999"></line><rect x="635" y="0" fill="#eaeaea" stroke="#666" width="150" height="65" rx="3" ry="3" class="actor"></rect><text x="710" y="32.5" style="text-anchor: middle; font-weight: 400; font-family: &quot;Open-Sans&quot;, &quot;sans-serif&quot;;" dominant-baseline="central" alignment-baseline="central" class="actor"><tspan x="710" dy="0">Online</tspan></text></g><defs><marker id="arrowhead" refX="9" refY="5" markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" orient="auto"><path d="M 0 0 L 10 5 L 0 10 z"></path></marker></defs><defs><marker id="crosshead" markerWidth="15" markerHeight="8" orient="auto" refX="16" refY="4"><path fill="black" stroke="#000000" style="stroke-dasharray: 0px, 0px;" stroke-width="1px" d="M 9,2 V 6 L16,4 Z"></path><path fill="none" stroke="#000000" style="stroke-dasharray: 0px, 0px;" stroke-width="1px" d="M 0,1 L 6,7 M 6,1 L 0,7"></path></marker></defs><defs><marker id="filled-head" refX="18" refY="7" markerWidth="20" markerHeight="28" orient="auto"><path d="M 18,7 L9,13 L14,7 L9,1 Z"></path></marker></defs><defs><marker id="sequencenumber" refX="15" refY="15" markerWidth="60" markerHeight="40" orient="auto"><circle cx="15" cy="15" r="6"></circle></marker></defs><g><rect x="-30.5" y="75" fill="#EDF2AE" stroke="#666" width="211" height="38" rx="0" ry="0" class="note"></rect><text x="75" y="80" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="noteText" dy="1em"><tspan x="75">Create/Import a wallet</tspan></text></g><g><rect x="-12.5" y="123" fill="#EDF2AE" stroke="#666" width="175" height="38" rx="0" ry="0" class="note"></rect><text x="75" y="128" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="noteText" dy="1em"><tspan x="75">Create a new pool</tspan></text></g><g><rect x="-89" y="171" fill="#EDF2AE" stroke="#666" width="328" height="38" rx="0" ry="0" class="note"></rect><text x="75" y="176" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="noteText" dy="1em"><tspan x="75">Rotate KES keys to generate op.cert</tspan></text></g><g><rect x="-77" y="219" fill="#EDF2AE" stroke="#666" width="304" height="38" rx="0" ry="0" class="note"></rect><text x="75" y="224" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="noteText" dy="1em"><tspan x="75">Create a backup w/o private keys</tspan></text></g><text x="393" y="272" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="messageText" dy="1em">Transfer backup to online node</text><line x1="75" y1="309" x2="710" y2="309" class="messageLine0" stroke-width="2" stroke="none" style="fill: none;" marker-end="url(#arrowhead)"></line><g><rect x="501" y="319" fill="#EDF2AE" stroke="#666" width="418" height="38" rx="0" ry="0" class="note"></rect><text x="710" y="324" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="noteText" dy="1em"><tspan x="710">Fund the wallet base address with enough Ada</tspan></text></g><g><rect x="459.5" y="367" fill="#EDF2AE" stroke="#666" width="501" height="38" rx="0" ry="0" class="note"></rect><text x="710" y="372" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="noteText" dy="1em"><tspan x="710">Register wallet using ' Wallet » Register ' in hybrid mode</tspan></text></g><text x="393" y="420" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="messageText" dy="1em">Transfer built tx file back to offline node</text><line x1="710" y1="457" x2="75" y2="457" class="messageLine0" stroke-width="2" stroke="none" style="fill: none;" marker-end="url(#arrowhead)"></line><g><rect x="-266.5" y="467" fill="#EDF2AE" stroke="#666" width="683" height="38" rx="0" ry="0" class="note"></rect><text x="75" y="472" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="noteText" dy="1em"><tspan x="75">Use ' Transaction &gt;&gt; Sign ' with payment.skey from wallet to sign transaction</tspan></text></g><text x="393" y="520" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="messageText" dy="1em">Transfer signed tx back to online node</text><line x1="75" y1="557" x2="710" y2="557" class="messageLine0" stroke-width="2" stroke="none" style="fill: none;" marker-end="url(#arrowhead)"></line><g><rect x="397.5" y="567" fill="#EDF2AE" stroke="#666" width="625" height="38" rx="0" ry="0" class="note"></rect><text x="710" y="572" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="noteText" dy="1em"><tspan x="710">Use ' Transaction &gt;&gt; Submit ' to send signed transaction to blockchain</tspan></text></g><g><rect x="577" y="615" fill="#EDF2AE" stroke="#666" width="266" height="38" rx="0" ry="0" class="note"></rect><text x="710" y="620" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="noteText" dy="1em"><tspan x="710">Register pool in hybrid mode</tspan></text></g><text x="393" y="693" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="messageText" dy="1em">Repeat steps to sign and submit built pool registration transaction</text><line x1="75" y1="730" x2="710" y2="730" style="stroke-dasharray: 3px, 3px; fill: none;" class="messageLine1" stroke-width="2" stroke="none"></line><g><line x1="65" y1="663" x2="720" y2="663" class="loopLine"></line><line x1="720" y1="663" x2="720" y2="740" class="loopLine"></line><line x1="65" y1="740" x2="720" y2="740" class="loopLine"></line><line x1="65" y1="663" x2="65" y2="740" class="loopLine"></line><polygon points="65,663 115,663 115,676 106.6,683 65,683" class="labelBox"></polygon><text x="90" y="676" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="labelText">loop</text><text x="417.5" y="681" text-anchor="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="loopText"><tspan x="417.5"></tspan></text></g><g><rect x="431" y="750" fill="#EDF2AE" stroke="#666" width="558" height="38" rx="0" ry="0" class="note"></rect><text x="710" y="755" text-anchor="middle" dominant-baseline="middle" alignment-baseline="middle" style="font-family: &quot;trebuchet ms&quot;, verdana, arial, sans-serif; font-weight: 400;" class="noteText" dy="1em"><tspan x="710">Verify that pool was successfully registered with ' Pool » Show '</tspan></text></g><g><rect x="0" y="808" fill="#eaeaea" stroke="#666" width="150" height="65" rx="3" ry="3" class="actor"></rect><text x="75" y="840.5" style="text-anchor: middle; font-weight: 400; font-family: &quot;Open-Sans&quot;, &quot;sans-serif&quot;;" dominant-baseline="central" alignment-baseline="central" class="actor"><tspan x="75" dy="0">Offline</tspan></text></g><g><rect x="635" y="808" fill="#eaeaea" stroke="#666" width="150" height="65" rx="3" ry="3" class="actor"></rect><text x="710" y="840.5" style="text-anchor: middle; font-weight: 400; font-family: &quot;Open-Sans&quot;, &quot;sans-serif&quot;;" dominant-baseline="central" alignment-baseline="central" class="actor"><tspan x="710" dy="0">Online</tspan></text></g></svg>



## Step 6b. Transfer tools from online to offline

We will zip the needed tools. 

```
mkdir -p /tmp/transfer/.cabal
cp -r $CNODE_HOME/scripts /usr/local/bin/cardano-* ~/.bashrc /tmp/transfer
cp -r ~/.cabal/bin /tmp/transfer/.cabal/
tar -czvf transfer.tar.gz /tmp/transfer/
```

Using `scp` or `WinSCP` transfer the tar.gz file offline.

Using scp:

```
scp -P <PORT_NUM> user@example.host.or.ip.com:/home/user/transfer.tar.gz .
```

With a USB, transfer to the air-gapped device.

Once on the device, use the terminal to extract the files. Replace the .bashrc with the new one. 

```
mv ~/.bashrc ~/.bashrc_original
cp ~/transfer/.bashrc ~
```

Make sure the .bashrc has the proper username, as the PATH variable set may be different.

```
sed -i 's/oldUserName/newUserName/g' INPUTFILE
```

Reset the enviroment

```
source ~/.bashrc
```

Add the cardano tools to the proper path

```
sudo cp ~/transfer/cardano-* /usr/local/bin
```

Confirm path / versions

```
cardano-cli version
# cardano-cli 1.25.1 - linux-x86_64 - ghc-8.10
# git rev 9a7331cce5e8bc0ea9c6bfa1c28773f4c5a7000f
cardano-node version
# cardano-node 1.25.1 - linux-x86_64 - ghc-8.10
# git rev 9a7331cce5e8bc0ea9c6bfa1c28773f4c5a7000f
```


## Step 7: Create the Pool

***THIS WILL BE ON THE OFFLINE DEVICE***



Create the pool in CNTools. 

```
cd $CNODE_HOME/scripts
./cntools.sh
```

In the menu, press P for pool. Then, press N for new pool. Type the name of the pool. This variable will be updated in the Producer env file in order to start it as a Producer.

Confirm the files are in `/opt/cardano/cnode/priv/pool/$POOL_NAME`

## Step 8: Confirm / Send ADA To Wallets.

Using CNTools, make sure that `pledge` wallet has the pool depsoit and pledge amount.

## Step 9: Register the Pool

Before this step, make sure you have the following:
- [] Pledge amount + 500 + few ADA for fees in the wallet
- [] Reward wallet with proper `rewards`
- [] git.io short link with Pool Meta data

Next, press P for pool, then, press R for register. Press O for online. Put in the parameters for Pledge, Margin, etc. 

Confirm the meta data output. Press Y.

For Pool Relay Reigster select 4 and put in one or more relays.

If you get the following, it was successful

![Example output](https://aws1.discourse-cdn.com/business4/uploads/cardano/original/3X/6/e/6e8e27c88768219d04bdad7849b9f98c16ade7dd.png)

Here's the testnet example

```
INFO: press any key to cancel and return (won't stop transaction)                                                                            [145/1314]
                                                                           
Pool test successfully registered!                                                                                                                     
Owner #1      : pledge                                                     
Reward Wallet :                                                                                                  
Pledge        : 1 Ada                                                      
Margin        : 7.5 %                                                      
Cost          : 340 Ada                                                    
                                                                           
Uncomment and set value for POOL_NAME in ./env with 'test'                 
                                                                                                                                              
INFO: Total balance in 1 owner/pledge wallet(s) are: 2.434901 Ada    
```



## Step 10 Start Producer as an actually Producer

```
cd $CNODE_HOME/scripts
vim env
```

Remove the # (comment) from the POOL_NAME and confirm it's name
```
#POOL_NAME=""  
POOL_NAME="test" 
```

Restart the node and confirm that it is in fact a CORE 

*The CERTIFICATIONS and KES need to be rotated (once/ ~90 days); In order to do that you must go to: CNTOOLS - POOL - ROTATE; after this operation restart your Producer and now in gliveview you should see the new KES expiration date.*

Step X - Securing Files

## Currect Problem: 


## Resource Credit 

- [Digital Ocean](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-20-04)
- [Cardano Documentation](https://docs.cardano.org/en/latest/getting-started/exchanges/index.html)
- [CNTools](https://cardano-community.github.io/guild-operators/#/Build/node-cli)
- [Cardano Stake Pool Course](https://cardano-foundation.gitbook.io/stake-pool-course/)
- [Coin Cashew Guides](https://www.coincashew.com/coins/overview-ada/guide-how-to-build-a-haskell-stakepool-node)
- [Alexd1985 Forum Post](https://forum.cardano.org/t/how-to-set-up-a-pool-in-a-few-minutes-and-register-using-cntools/48767)
- [Tmux guide](https://linuxhandbook.com/tmux/)
- [More bash scripts](https://github.com/gitmachtl/scripts)
- [Cardano Latest topology / config files](https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/index.html)
