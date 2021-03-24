# Cardano Recipe

## Step 1a. Start block producer server

Go to Digital Ocean. We are creating 2 droplets, one relay, one block producer. We will first start creating the block producer.

OS: Ubuntun 20.04 (LTS) x64
- Block Producer
  - 8GB RAM

Once the nodes are stared, update the server

## Step 1b. Harden server basics

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
# whitelisted IP addresses
# ignoreip = INSERT_A_SAFE_IP_HERE_IF_DESIRED
```

For ignoreip, if there is a specific IP address that is used, remove the # (comment) and space and add the IP address after the equals. For example

```
ignoreip = 127.0.0.1
```

Restart fail2ban for setting to take effect

```
sudo systemctl restart fail2ban
```

### Configure Firewall

The standard UFW firewall can be used to control network access to your node.
With any new installation, ufw is disabled by default. Enable it with the following settings.
Port 22 (or your random port #) TCP for SSH connection
Port 600 (or your random p2p port #) TCP for p2p traffic


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

Replace <RELAY NODE PORT> with your public relay port, replace the 5 with your preferred connection limit.

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

Port 3000 TCP for Grafana web server (if hosted on current node)
Port 9090 tcp for Prometheus export data (optional, if hosted on current node)

## Step 1b + 2b. Create Relay server

Follow the same steps as step 1a and 2a, except with a relay server. 

The only difference will be when setting up the firewall.

## Step 3: Build cardano-node and cardono-cli

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

Once complete, we should have all the packages, we can build cardano-node

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


## Step 5: Create wallet and Register the Pool

Alexd1985's recommendation is to create a new wallet for pool registration and transactions fees only, and pledge with an imported wallet (this way you will have control of your funds better). 

Create a wallet named `rewards`

```
cd $CNODE_HOME
./cntools.sh
```

Press W for the wallet command, then N for new wallte, and the put in the name as seen above.

Then, Press W, next press I to import a new wallet, finally press M to input a mnemoic seed. Nmae this wallet `pledge`. You may get an error about `bech32`. If you do, re-run the prereq script and rebuild the node. Then confirm that the bech32 and cardano-address are in the ~/.cabal/bin folder. Here are the instructions:

```
cd "$HOME/tmp"
curl -sS -o prereqs.sh https://raw.githubusercontent.com/cardano-community/guild-operators/master/scripts/cnode-helper-scripts/prereqs.sh
chmod 755 prereqs.sh
```

```
./prereqs.sh
. "${HOME}/.bashrc"
```

Check the `$HOME/.bashrc` file to make sure enviroment variables are set properly. You can echo it on the command line to confirm as well

```
echo $CNODE_HOME
```

```
cd ~/git
rm -rf cardano-node
git clone https://github.com/input-output-hk/cardano-node
cd cardano-node
```

```
git fetch --tags --all
# Replace tag against checkout if you do not want to build the latest released version
git pull
git checkout $(curl -s https://api.github.com/repos/input-output-hk/cardano-node/releases/latest | jq -r .tag_name)

$CNODE_HOME/scripts/cabal-build-all.sh -o
```

```
cd ~/.cabal/bin
ls -l
```

## Step 6: Create Pool Meta Data on Github.

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

## Step 7: Create the Pool


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

## Resource Credit 

- [Digital Ocean](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-20-04)
- [Cardano Documentation](https://docs.cardano.org/en/latest/getting-started/exchanges/index.html)
- [CNTools](https://cardano-community.github.io/guild-operators/#/Build/node-cli)
- [Cardano Stake Pool Course](https://cardano-foundation.gitbook.io/stake-pool-course/)
- [Coin Cashew Guides](https://www.coincashew.com/coins/overview-ada/guide-how-to-build-a-haskell-stakepool-node)
- [Alexd1985 Forum Post](https://forum.cardano.org/t/how-to-set-up-a-pool-in-a-few-minutes-and-register-using-cntools/48767)
- [Tmux guide](https://linuxhandbook.com/tmux/)
