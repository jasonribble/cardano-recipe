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
Port 3000 TCP for Grafana web server (if hosted on current node)
Port 9090 tcp for Prometheus export data (optional, if hosted on current node)

```
ufw allow <22 or your random port number>/tcp
ufw allow <6000 or your random p2p port number>/tcp
ufw allow 3000/tcp
ufw enable
ufw status numbered
```

A) *Run this on your Block Producer only:*
Only your Relay Node(s) should be permitted access to your Block Producer Node.

```
sudo ufw allow proto tcp from <RELAY NODE IP> to any port <BLOCK PRODUCER PORT>
# Example
# sudo ufw allow proto tcp from 18.58.3.31 to any port 6000
```

B) *Run this on your Relay(s) only:*
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

We will open up ports for monitoring at a later time.

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

## Resource Credit 

- [Digital Ocean](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-20-04)
- [Cardano Stake Pool Course](https://cardano-foundation.gitbook.io/stake-pool-course/)
- [Coin Cashew Guides](https://www.coincashew.com/coins/overview-ada/guide-how-to-build-a-haskell-stakepool-node)
- [Tmux guide](https://linuxhandbook.com/tmux/)
- [CNTools](https://cardano-community.github.io/guild-operators/#/Build/node-cli)
- [Cardano Documentation](https://docs.cardano.org/en/latest/getting-started/exchanges/index.html)
