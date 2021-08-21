# Cardano Recipe

This guide is a collection of guides tailored to our specific situation. Their may be flaws in this setup, so please be dilligent in using these instructions. 

## Requirements

- Block Producer
  - 8GB RAM
  - OS: Ubuntun 20.04 (LTS) x64
- Relay1...RelayN
  - 8GB RAM
  - OS: Ubuntun 20.04 (LTS) x64
- Offline Device
  - TailsOS / Ubuntu 20.04 (LTS) x64USB
  - Transfer USB
- Funds:
  - `rewards` wallet
  - `pledge` wallet
    - includes 500 ADA + fees for pool deposit

## Step 1a. Start block producer server

Go to Digital Ocean. We are creating 2 droplets, one relay, one block producer. We will first start creating the block producer.

Once the nodes are stared, update the server

## Step 1b. Harden server

### Add user

SSH in to the server

Add a new user with a unique password. We suggest using a password manager to generate a strong password.

```
adduser cardano
```

Add user to `sudo` group to have proper privledges ot the system.

```
usermod -aG sudo cardano
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
- Port 6000 (or your random p2p port #) TCP for p2p traffic


A) *Run this on your Block Producer only:*
Only your Relay Node(s) should be permitted access to your Block Producer Node.


```
sudo ufw allow <22 or your random port number>/tcp
sudo ufw enable
sudo ufw status numbered
```

```
sudo ufw allow proto tcp from <RELAY NODE IP> to any port <BLOCK PRODUCER PORT>
# Example
# sudo ufw allow proto tcp from 18.58.3.31 to any port 6000
```

B) *Run this on your Relay(s) only:*


```
sudo ufw allow <22 or your random port number>/tcp
sudo ufw allow <6000 or your random p2p port number>/tcp
sudo ufw enable
sudo ufw status numbered
```

In order to protect your Relay Node(s) from a novel "DoS/Syn" attack, Michael Fazio created iptables entry which restricts connections to a given destination port to 5 connections from the same IP. 

Replace <RELAY NODE PORT> with your public relay port. Opitonally, you can replace the 5 with your preferred connection limit.

```
sudo iptables -I INPUT -p tcp -m tcp --dport <RELAY NODE PORT> --tcp-flags FIN,SYN,RST,ACK SYN -m connlimit --connlimit-above 5 --connlimit-mask 32 --connlimit-saddr -j REJECT --reject-with tcp-reset
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
./prereqs.sh -l # we will need the libsodium fork to bring offline.
source "$HOME/.bashrc"
```

Check the `$HOME/.bashrc` file to make sure enviroment variables are set properly. You can echo it on the command line to confirm as well
```
echo $CNODE_HOME
```

## Step 3a: Install cardano-node (with CNTools) 

Once complete, we should have all the packages, we can build cardano-node, cardano-cli and more.

Clone the cardano-node repo

```
cd "$HOME/git"; # note that CNTools prereq script put this here
git clone https://github.com/input-output-hk/cardano-node;
cd cardano-node
```

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

*If you haven't already*, add a rule in Relay FIREWALL to allow connections from all public Relay on port RELAY_PORT ( where RELAY_PORT is the CNODE PORT configured in env file):

```
sudo ufw allow proto tcp from any to any port RELAY_PORT
```

Make sure the firewall is set properly on all nodes.
```
sudo ufw status
```

Deploy as a systemd service

```
cd $CNODE_HOME/scripts
./deploy-as-systemd.sh
```

*IMPORTANT to know when you run ./deploy-as-systemd.sh:*
It will ask also to set the topologyupdater process as systemd and you will:

- Producer: press NO for topologyUpdater
- Relay: press YES for topologyUpdater, let the default timer for cnode auto restart to 86400

>Since the test network has to get along without the P2P network module for the time being, it needs static topology files. This “TopologyUpdater” service, which is far from being perfect due to its centralization factor, is intended to be a temporary solution to allow everyone to activate their relay nodes without having to postpone and wait for manual topology completion requests.

Learn more at [CNTools Topology Update](https://cardano-community.github.io/guild-operators/#/Scripts/topologyupdater) page

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



## Step 6a. Transfer tools from online to offline

We will zip the needed tools. It shoudld be the following:
```
~/.bashrc
~/.cabal/
~/.cabal/bin/
~/.cabal/bin/db-analyser 
~/.cabal/bin/cardano-address
~/.cabal/bin/bech32
~/.cabal/bin/cardano-node
~/.cabal/bin/db-converter
~/.cabal/bin/tracer-transfomers-example2
~/.cabal/bin/cardano-node-chairman
~/.cabal/bin/cardano-ping
~/.cabal/bin/cardano-cli
~/.cabal/bin/tracer-transfomers-example1
~/.ghcup/
$CNHOME/scripts/
$CNHOME/scripts/stack-build.sh                    
$CNHOME/scripts/sLiveView.sh                      
$CNHOME/scripts/deploy-as-systemd.sh
$CNHOME/scripts/system-info.sh
$CNHOME/scripts/topologyUpdater.sh
$CNHOME/scripts/logMonitor.sh                     
$CNHOME/scripts/cntools.config                    
$CNHOME/scripts/.env_branch                       
$CNHOME/scripts/gLiveView.sh                      
$CNHOME/scripts/cabal-build-all.sh
$CNHOME/scripts/balance.sh                        
$CNHOME/scripts/cncli.sh                          
$CNHOME/scripts/cntools.library
$CNHOME/scripts/setup_mon.sh                      
$CNHOME/scripts/env                               
$CNHOME/scripts/cnode.sh                          
$CNHOME/scripts/sendADA.sh                        
$CNHOME/scripts/createAddr.sh                     
$CNHOME/scripts/itnRewards.sh                     
$CNHOME/scripts/rotatePoolKeys.sh
$CNHOME/scripts/cntools.sh           
```

```
cd "$HOME"
mkdir -p ~/tmp/transfer/.cabal
mkdir ~/tmp/transfer/.ghcup
mkdir ~/tmp/lib
cp -r $CNODE_HOME/scripts ~/.bashrc ~/tmp/transfer
cp -r /usr/local/lib/libsodium* ~/tmp/transfer
cp -r ~/.ghcup/env ~/tmp/transfer/.ghcup
cp -r ~/.cabal/bin ~/tmp/transfer/.cabal
mkdir -p ~/tmp/transfer/.cabal
mkdir ~/tmp/transfer/.ghcup
cp -r $CNODE_HOME/scripts ~/.bashrc ~/tmp/transfer
cp -r /usr/local/lib/libsodium* ~/tmp/transfer/lib
cp -r ~/.ghcup/env ~/tmp/transfer/.ghcup
cp -r ~/.cabal/bin ~/tmp/transfer/.cabal
```

Confirm you have the right files. 

```
tree -a ~/tmp/transfer
```

Zip up the files

```
cd "$HOME"
tar czvf transfer.tar.gz tmp/transfer
```

Using `scp` or `WinSCP` transfer the tar.gz file offline.

Using scp:

```
scp -P <PORT_NUM> user@example.host.or.ip.com:/home/cardano/transfer.tar.gz .
```

Then copy this file to a 2nd USB (not the one with the OS on it.). It is also suggested to have a copy of this README.md. It provides an easy way to copy the commands.

With a USB, transfer to the air-gapped device. If using tails, make sure to have persistance and admin password enabled.

Once on the device, copy or move the `transfer.tar.gz` to the home folder. Use the terminal to extract the files.  

```
tar xzvf transfer.tar.gz
```

It should now be in a folder here `~/tmp`. We can check with

```
ls -lah ~/tmp/transfer
```

Replace the .bashrc with the new one.
```
mv ~/.bashrc ~/.bashrc_original
cp ~/tmp/transfer/.bashrc .
```

If needed, make sure the .bashrc has the proper username, as the PATH variable set may be different. 

```
vim ~/.bashrc
```
 
On the local machine, add the cardano tools to the proper path

```
mkdir -p /home/$USER/.cabal/
cp -r ~/tmp/transfer/.cabal/bin /home/$USER/.cabal
```

Add libsodium and friends to the shared bin

```
sudo cp ~/tmp/transfer/lib/* /usr/local/lib/
```

Add GHC enviroment
```
cp -r ~/tmp/tranfser/.ghcup .
```

Reset the enviroment

```
source ~/.bashrc
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


## Step 6: Create / Import wallet 

Go to [CNTools Offline Work](https://cardano-community.github.io/guild-operators/#/Scripts/cntools?id=offline-workflow) and see the diagram. we will keep our keys save with a hybrid pool creation of our wallet(s) and 

***THIS WILL BE ON THE OFFLINE DEVICE***

On the offline device, use CNTools to either create or import 2 wallets. One will be called `pledge`, which will be our main pledge amount and 500 ADA for the pool deposit (yes, you can get the depsoit back). This will be kept offline, to safe guard our funds. The other one will be caled `rewards`. Clearly, to recieve the rewards for being a stake pool operator. We also want this one safe. 

You may want to make backups of these keys, in the event that the USB / offline device dies randomly some how. This is very possible.

We can create or import the wallet using `cntools.sh` once again. See CNTools for the example to [create a wallet](https://cardano-community.github.io/guild-operators/#/Scripts/cntools-common?id=create-wallet).

*Note that if you’d like to use Import function to import a Daedalus/Yoroi based 15 or 24 word wallet seed, please ensure that you’ve rebuilt your cardano-node using instructions here or alternately ensure that cardano-address and bech32 are available in your $PATH environment variable.*


## Step 7: Create the Pool

***THIS WILL BE ON THE OFFLINE DEVICE***

Create the pool in CNTools. 

```
cd $CNODE_HOME/scripts
./cntools.sh
```

In the menu, press P for pool. Then, press N for new pool. Type the name of the pool. This variable will be updated in the Producer env file in order to start it as a Producer.

Confirm the files are in `/opt/cardano/cnode/priv/pool/$POOL_NAME`

Using the same `cntools.sh` script, create a backup of the pool so we can restore it to the Block Producer to register the pool on the mainnet.

 
## Step 9: Register the Pool

Before this step, make sure you have the following:
- [] Pledge wallet has PLEDGE_AMOUNT + 500 + few ADA for fees in the wallet; named `pledge`
- [] Reward wallet with proper `rewards`
- [] git.io short link with Pool Meta data

Next, press P for pool, then, press R for register. Press O for online. Put in the parameters for Pledge, Margin, etc. 

Confirm the meta data output. Press Y.

For Pool Relay Reigster select 4 and put in one or more relays.

If you get the following, it was successful

![Example output](https://aws1.discourse-cdn.com/business4/uploads/cardano/original/3X/6/e/6e8e27c88768219d04bdad7849b9f98c16ade7dd.png)

Here's the testnet example, of course, with poor formating

```
INFO: press any key to cancel and return (won't stop transaction)                                                                            [145/1314]
                                                                           
Pool test successfully registered!                                                                                                                     
Owner #1      : pledge                                                     
Reward Wallet : reward                                                                                    
Pledge        : 1 Ada                                                      
Margin        : 7.5 %                                                      
Cost          : 340 Ada                                                    
                                                                           
Uncomment and set value for POOL_NAME in ./env with 'test'
                                                                                                                       
INFO: Total balance in 1 owner/pledge wallet(s) are: 2.434901 Ada    
```

## Step 10 Start Producer as an actually Producer

If you haven't already, make sure the Producer has the proper POOL_NAME
```
cd $CNODE_HOME/scripts
vim env
```

Remove the # (comment) from the POOL_NAME and confirm it's name
```
#POOL_NAME=""  
POOL_NAME="test" 
```

Restart the node and confirm that it is in fact a CORE. It may take a little bit of time to sync for it to say "core". 

*The CERTIFICATIONS and KES need to be rotated (once/ ~90 days); In order to do that you must go to: CNTOOLS - POOL - ROTATE; after this operation restart your Producer and now in gliveview you should see the new KES expiration date.*

***Congratulations. You have create a block producer on the Cardano blockchain***

## Future Steps

- Setting up Monitoring (Prometheus + Grafana + Node Exporter)
- Rotating the operation certs

## Optional Steps

- Setting up 2FA PAM module for SSHing into the servers

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
