# DXSpider node in a container

The following document describes how to deploy DXSpider software
in a container. A container is used in order to control 
node environment and separate it from the host.
This method was tested on Linux but it should be easy to convert it
to Windows and MacOS. 

## Prerequisites
* Docker must be running on a host
* User must be a member of `docker` group.

**DO NOT RUN THIS AS ROOT!**

## Build a container

Use `Dockerfile` from this repository to build an image for DXSpider node. 
Pay attention to the build command. Two arguments are passed `USERID` and `GROUPID`.
Those arguments will match user id and user's group id from the host. This is important 
as those values will be mapped to a user inside container in order to allow interaction 
with mounted volumes.

To build an image execute:
```
docker build --build-arg USERID=`id -u` --build-arg GROUPID=`id -g` . -t dxenv
```
If no errors are encountered, an image named `dxenv` should be created.

## Node setup
The following steps describe the configuration process for a personal node. 
I used my callsign SP6XD and its variation SP6XD-2 as the node callsign. 
Update the configuration file with your own callsign.

### Initial setup

Create dedicated folder for DXSpider:
```
mkdir ~/DXSpider
cd ~/DXSpider
```

Clone DXSpider repository inside `~/DXSpider` and switch to **mojo** branch:
```
git clone git://scm.dxcluster.org/scm/spider
cd spider/
git checkout --track -b mojo origin/mojo
cd -
```

Prepare configuration templates:
```
mkdir spider/local
cp spider/perl/DXVars.pm.issue spider/local/DXVars.pm
cp spider/perl/Listeners.pm spider/local/Listeners.pm
```

Edit `spider/local/DXVars.pm` and update node details:
```
$mycall = "SP6XD-2";
$myname = "Bart";
$myalias = "SP6XD";
$mylocator = "JO81";
$myqth = "Wroclaw";
$myemail = "sysop@gmail.com";
```
Note: `$mycall` will be used to define node callsign.


Edit `spider/local/Listeners.pm` and uncomment line with IPv4 (and IPv6 if applicable):
```
# remove the '#' character from the next line to enable the listener!
           ["0.0.0.0", 7300]
```

Execute `create_sysop.pl` script:
```
docker run -v `pwd`/spider:/spider dxenv /spider/perl/create_sysop.pl
```
The following result should be visible:
```
(*) DXUser finished
```
That's it. Initial configuration is completed. 

### Start a node
In order to start DXSpider node execute:
```
docker run --restart unless-stopped --name dxspider -d -v `pwd`/spider:/spider -p 7300:7300 dxenv
```
The above command will create a container named `dxspider` that uses previously created `dxenv` image. 
In this example, `~/DXSpider/spider` is mounted inside the container as `/spider`, and port 7300 is redirected. 
`~DXSpider/spider` folder contains cloned repository and is used as root folder for DXSpider node inside container.
The container runs as a daemon in the background and will start automatically upon reboot. 

Check if the container is running:
```
docker ps
```
The result should be similar to this:
```
CONTAINER ID   IMAGE     COMMAND                  CREATED         STATUS         PORTS                                       NAMES
bd347def18f4   dxenv     "perl -w /spider/per…"   2 seconds ago   Up 2 seconds   0.0.0.0:7300->7300/tcp, :::7300->7300/tcp   dxspider
```
This means DXSpider node is up and running. At this point your node is ready to receive spots and exchange them between connected users.
You may use telnet to verify the node is accessible from remote locations: 
```
telnet host_running_container_ip 7300
```


### Set up CW skimmer

To connect to a remote node or skimmer, you must create a connection file. 
The filename should match the remote node or skimmer name. 
For reverse beacon or skimmer nodes, any name can be used. In this example, 
the connection script will use the telnet method and identify itself as `SP6XD-2`.

Create a file `spider/connect/sk0mmr`. SK0MMR name will be used to describe RBN CW node.
```
connect telnet telnet.reversebeacon.net 7000
'call:' 'SP6XD-2'
```

Connect to the cluster interactive console:
```
docker exec -ti dxspider /spider/perl/console.pl
```

The following commands are meant to be executed in DXSpider console.

Set up RBN node and connect:
```
set/rbn sk0mmr
connect sk0mmr
```

Verify the connection is established:
```
links
```

### Set up FT skimmer

Create separate file `spider/connect/sk1mmr`. SK1MMR name will be used to describe RBN FT node.
```
connect telnet telnet.reversebeacon.net 7001
'call:' 'SP6XD-2'
```

Connect to the cluster console:
```
docker exec -ti dxspider /spider/perl/console.pl
```

Execute the following commands in DXSpider console:
```
set/rbn sk1mmr
connect sk1mmr
```

Verify the connection is established:
```
links
```

### Note on skimmers

By default, skimmer spots are disabled. Each user has individual control over skimmer spots. 
The following skimmer commands are available:
* `set/skimmer` - enable all skimmer spots
* `set/skimmer CW` - enable CW skimmer spots only
* `set/skimmer FT` - enable FT skimmer spots only
* `set/skimmer RTTY` - enable RTTY skimmer spots only
* `set/skimmer PSK` - enable PSK skimmer spots only
* `unset/skimmer` - disable all skimmer spots

Combinations are possible
* `set/skimmer RTTY PSK` - enable PSK and RTTY skimmer spots only

### Crontab 
Create a `spider/local_cmd/crontab` file to ensure that connections to the skimmer 
or nodes are established upon restart or after disconnection.
```
* * * * * start_connect('sk0mmr') unless connected('sk0mmr')
* * * * * start_connect('sk1mmr') unless connected('sk1mmr')
```
This command will be executed every minute. This file uses stanard crontab scheduler
definition.

### Startup commands 
It's possible to defile node and user startup commands. 

* Node

Create `spider/scripts/startup` file. Now it's possible to define variables and execute 
commands upon startup. For example: 

```
set/rbn sk0mmr
connect sk0mmr
```

* User
Create `spider/scripts/user_default` file. Now it's possible to define variables and execute 
commands upon user login. For example: 

```
blank
sh/time
blank
```
It's possible to define individual start up files. Filname must match user callsign.

### Enable registration

It's recommended to enable registration requirement. Only registered users are allowed to send spots 
and announcements. Unregistered ones will be allowed to receive spots only. 

Edit previously created `startup` file and add:
```
set/var $main::reqreg = 1
```

Register user in DXSpider console: 
```
register PUT_USER_CALLSIGN
```

### MOTD files

It's possible to setup two types of MOTD files. 
* `spider/local_data/motd` - message of the day file for all registered users
* `spider/local_data/motd_nor` - message of the day file for all unregistered users

If your node requires registration, add this information to `motd_nor` file.

## Linking w other nodes

This step requires both parties to set up a connection. Remote node sysop must add your local node 
as `dxspider` to establish node link and exchange spots. This is important, as it is impossible to 
set up the connection from only one side. Assuming your node was already added to the remote one,
you may setup and initiate a connection. In this example connection to `SP6PWS-2` node will be presented: 

### Set up connection file

Create `spider/connect/sp6pws-2` file: 
```
connect telnet dxcluster.sp6pws.pl 7300
'ogin:' 'SP6XD-2'
```

In DXSpider console execute:
```
set/spider sp6pws-2
connect sp6pws-2
```
This command will add SP6PWS-2 as `dxspider` node to your node, and will try to connect to it. 

You may verify connection by executing `links` command in the DXSpider console:
```
 Callsign Type Started                 Uptime    RTT Count Int.  Ping Iso? In  Out PC92? Address
  SP6PWS-2 DXSP 26-Jul-2024 2143Z           5s   0.04   2    300   450               Y    46.242.130.241
```

Please note, SP6PWS-2 is a real node in a cluster network. If you want to setup a link with this node, 
please contact me first. You may get contact details by connecting to SP6PWS-2 as a user:
```
telnet dxcluster.sp6pws.pl 7300
```

### Crontab and startup for nodes

Create an entry in `spider/local_cmd/crontab`: 
```
0,15,30,45 * * * * start_connect('sp6pws-2') unless connected('sp6pws-2')
```
This command will try to connect to SP6PWS-2 node every 15 minutes. 
You may also want to update `spider/scripts/startup` file:
```
set/spider sp6pws-2
connect sp6pws-2
```

## Useful commands
* `who` - show connected entities (users,nodes,skimmers)
* `links` - show links only
* `show/log` - display log file. You may also want to check `spider/local_data/log` and `spider/local_data/debug` folders

## Useful links
* [DXSpider wiki](https://wiki.dxcluster.org/index.php/Main_Page) - DXSpider documentation, commands reference
* [DXCluster.info](https://www.dxcluster.info/telnet/index.php) telnet directory - useful for contacting other sysops
* [dxcluster.sp6pws.pl 7300](telnet://dxcluster.sp6pws.pl:7300) - SP6PWS-2 DXSpider node
* [dxcluster.org](http://www.dxcluster.org/main/) - DXSpider documentation on dxcluster.org (legacy?)

