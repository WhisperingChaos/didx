# didx
Configures and starts a 'Docker In Docker' (dind) server container with its own, empty local repository and spins up an associated docker client container.  Once dind server and client have started, '''didx''' executes one or more scripts/programs within context of the dind client container.

Use didx to create a Docker test environment that's automatically destroyed after all tests successfully complete.
#####ToC
[Options](#options)  
&nbsp;&nbsp;&nbsp;&nbsp;[--sv,--cv](#--sv--cv)    
&nbsp;&nbsp;&nbsp;&nbsp;[--pull](#--pull)  
&nbsp;&nbsp;&nbsp;&nbsp;[--cp[],-v[]](#--cp-v)  
&nbsp;&nbsp;&nbsp;&nbsp;[--clean](#--clean)  
&nbsp;&nbsp;&nbsp;&nbsp;[--storage-driver](#--storage-driver)  
&nbsp;&nbsp;&nbsp;&nbsp;[--cv-env](#--cv-env)  
[Examples](#examples)  
[Installing](#install)  
[Testing](#testing)  
[Warning Label](#warning-label)  
[Motivation](#motivation)  
[License](#license)  
```

Usage: didx.sh [OPTIONS] {| COMMAND [COMMAND] ...}

  COMMAND -  Command executed within context of Docker in Docker (dind)
             client container.

  Use local Docker Engine to run a Docker Engine container cast as the "server".
  Once started, run second Docker Engine container cast as the "client".  After
  the client starts, copy or mount zero or more files into the client's
  file system then execute one or more COMMANDS within the client container.

  The server container's local repository is encapsulated as a data volume
  attached to only this server.  This configuration isolates image and container
  storage from the repository used by the Docker Engine server initiating
  this script.  

OPTIONS:
  --sv                       Docker server version.  Defaults to most recent
                               stable (public) Docker Engine version.  Click
                               https://hub.docker.com/r/library/docker/tags/ to
                               view supported versions.
  --cv                       Docker client version.  Defaults to --sv value.
  -p,--pull=false            Perform explicit docker pull before running server/client.
  --cp[]                     Copy files from source location into container running 
                               Docker client. (Optional)  
                               Format: <SourceSpec>:<AbsoluteClientContainerPath>
                                 <SourceSpec>-><hostFilePath>
                                 <SourceSpec>-><stream>->-
                                 <SourceSpec>->{<containerName>|<UUID>}:<AbsoluteContainerPath>
                                 <SourceSpec>->{<imageName>[:<tag>]|<UUID>}::<AbsoluteImagePath>
                               'docker cp' used when <SourceSpec> referrs to host file or
                               input stream.  Otherwise, when source refers to 
                               container or image, cp performed by 'dkrcp'.
  -v[]                       Mount host file system references or create an anynomous
                               volume in the container running Docker client. (Optional)
                               Format: [{<HostFilePath>|<VolumeFilePath>}:]<AbsoluteClientContainerPath>
                               'docker run -v' option used to implement mount.
  --clean=none               After executing all COMMANDs, sanitize environment.  Note
                               if an option value preserves the server's data volume,
                               you must manually delete it using the -v option when 
                               removing the server's container.
                               none:    Leave server & client containers running
                                        in background.  Preserve server data volume.
                               success: When all COMMANDs succeed, terminate and
                                        remove server & client containers.
                                        Delete server data volume.
                               failure: When at least one COMMAND fails, terminate
                                        and remove server & client containers
                                        Delete  server data volume.
                               anycase: Regardless of COMMAND exit code, terminate
                                        and remove server, client containers.
                                        Delete server data volume.
                               all:     Remove all server, client containers from
                                        local repository. If necessary, terminate
                                        running instances.
                                        Delete all server data volumes.
  -s,--storage-driver        Docker storage driver name.  Determines method
                                applied to physically represent and manage images and
                                containers stored locally by the Docker server container.
                                Value defaults to the one utilized by the Docker instance
                                managing the Docker server container.  
  --cv-env=DIND_CLIENT_NAME  Environment variable name which contains the Docker client's
                               container name.  Use in COMMAND to identify client container.
  -h,--help=false            Don't display this help message.
  --version=false            Don't display version info.

```
A detailed explaination of [Docker in Docker (dind)](https://hub.docker.com/_/docker/).

##Options
####--sv,--cv
```--sv``` Determines the Docker Engine dind image version to run as the server container.  ```didx``` converts the version specifier to the appropriate dind tag.  The conversion simply appends *-dind* to the provided version specifier, except in the case of *'latest'* which fetches the most recent dind version.  The  list of dind supported versions can be derived by removing the *-dind* suffix from [dind tags](https://hub.docker.com/r/library/docker/tags/).  

```--cv``` Determines the Docker client image to run as the client container (separate from the server).  When running, the client container is [linked](https://docs.docker.com/v1.8/userguide/dockerlinks/) to the dind server container.  Although the Docker client and server container versions are typically identical, they can differ.  If ```--cv``` is omitted, ```didx``` will match the client version to the one specified by ```--sv```.

####--pull
```--pull``` directs ```didx``` to perform an explicit [```docker pull```](https://docs.docker.com/engine/reference/commandline/pull/) before executing ```docker run``` to refresh the Docker Engine Host's local repository with the most recent version of both the dind server and client images.  ```--pull``` is typically unnecessary when specifying a particular version specifier, like 1.11.  However, when describing the dind version using an adaptable lable, like *'latest'* or in situations where Docker has updated a specific image version, the local repository image of the dind server and/or client offered by the Docker Engine Host may be stale.  For example, *'latest'* may refer to an older Docker Engine version, as one or more releases may have occurred since the initial ```docker pull``` populated the local repository.

####--cp[],-v[]
```--cp``` adapts the client container's file system by adding/modifying any number of files to it.  ```--cp``` source files to can reside in the Docker Engine Host file system, container, or image.  They can also be streamed as a tar.  These various source types determine the copy method applied to transfer files from one or more sources to the targeted file system in the client container.  Files sourced from the Docker Engine Host file system or a streamed tar employ [```docker cp```](https://docs.docker.com/engine/reference/commandline/cp/) while sources types referencing container or image file systems use [```dkrcp.sh```](https://github.com/WhisperingChaos/dkrcp#dkrcp).  Due to its non Docker affliated status, ```dkrcp.sh``` isn't immediately available, as opposed to ```docker cp```, therefore, it must be downloaded from Github and installed on the Docker Engine Host in a location accessible via the host's PATH or through an alias.

Zero to many ```--cp``` instances may be specified as options to ```didx```.  The source files are copied to the client container in   left to right order.  The productions below define the expected format.

```
--cp option format:
   <SourceSpec>:<AbsoluteClientContainerPath>
      <SourceSpec>-><HostFilePath>
      <SourceSpec>-><Stream>
      <SourceSpec>->{<ContainerName>|<UUID>}:<AbsoluteContainerPath>
      <SourceSpec>->{<ImageName>|<UUID>}::<AbsoluteImagePath>
      
      <HostFilePath>->{<AbsoluteFilePath>|<RelativeFilePath>}
      <Stream>->-
      <ContainerName>->^[a-zA-Z0-9][a-zA-Z0-9_.-]*
      <ImageName>->[<NameSpace>/...]<RepositoryName>:[<TagName>]
      <NameSpace>, <RepositoryName>->^[a-z0-9][a-z0-9._-]*
      <TagName>->[A-Za-z0-9._-]+
      <AbsoluteContainerPath>-><AbsolutePath>
      <AbsoluteImagePath>-><AbsolutePath>
      <AbsoluteClientContainerPath>-><AbsolutePath>
      <AbsolutePath>->/.*
      <RelativeFilePath>->./.*
      
    Ex: /host/file:/client/container/target/                        # <SourceSpec>-><HostFilePath>
    Ex: -:/client/container/target/                                 # <SourceSpec>-><Stream>
    Ex: dreamy_pare:/some/container/file:/client/container/target/  # <SourceSpec>-><ContainerName>
    Ex: alpine:3.3::/tmp/file:/client/container/target/             # <SourceSpec>-><ImageName>

  Ultimately, the format of <SourceSpec> conforms to the ones expected by docker cp and dkrcp.sh.
```
Use this copy mechanism to dynamically extend the client container's abilities by installing processes implemented as scripts/programs.  Execution of added scripts/programs can be initiated by issuing a COMMAND to run them.  Since the dind server and client Docker images include [Alpine Linux](https://en.wikipedia.org/wiki/Alpine_Linux) in their derivation chains and this distro includes a package management feature, the client container can implement processes of arbitary complexity by combining the capabilities of ```--cp```, Apline's [apk package manager](http://wiki.alpinelinux.org/wiki/Alpine_Linux_package_management) and [busybox's](https://en.wikipedia.org/wiki/BusyBox) [Almquist Shell (ash)](https://en.wikipedia.org/wiki/Almquist_shell).  If scripts require full bash compatibility, encode a process the runs apk to install bash before executing them. 

Similar to ```--cp```, ```-v``` (volume) command extends the client container contents, however, it uses Docker's [volume](https://docs.docker.com/engine/userguide/containers/dockervolumes/) feature to bind the desired files from some source, like Docker Engine Host file system or a named volume, to the client container's file system instead of physically copying the files as implemented by ```--cp```.

Since ```-v``` supports the creation of anynomous volumes, ```didx``` will destroy the client container's anynomous volumes if it has been directed to via the ```--clean``` option value.
```
-v option format:
   [<SourceSpec>:]<AbsoluteClientContainerPath>
      <SourceSpec>-><HostFilePath>
      <SourceSpec>-><NamedVolumeFilePath>

      <HostFilePath>->{<AbsoluteFilePath>|<RelativeFilePath>}
      <NamedVolumeFilePath>->?  # not currently sure of its definition.
      <AbsoluteClientContainerPath>-><AbsolutePath>
      <AbsolutePath>->/.*
      <RelativeFilePath>->./.*
      
    Ex: /host/file:/client/container/target/                        # <SourceSpec>-><HostFilePath>
    Ex: named-volume:/named/volume/file:/client/container/target/   # <SourceSpec>-><ContainerName>
    Ex: /client/container/target/volume                             # Creates an anonymous volume.
    
  Ultimately, the format of -v conforms to -v option of docker run.
```
Use both ```--cp``` and ```-v``` to concurrently extend the client container.  ```didx``` applies the ```-v``` option before considering ```-cp```.  This ordering permits the creation of anynomous volumes associated to the client container enabling ```--cp``` to target a file path within the anynomous volume.

#####```--cp``` VS ```-v```
In general use ```--cp```:
  * for smallish files,
  * to physically encapsulate and couple the copied file's existance (life cycle) to the client container,
  * to reduce the dynamics introduced by ```-v```.

Use ```-v```:
  * for large files, 
  * when the file's life cycle is independent of the client container.

####--clean
Represents the function that destroys dind server and client containers including any anynomous volumes associated to them.  This option's value defines the triggering condition that causes the function's invocation.  For example, a value of *'success'* invokes the clean function if every COMMAND successfully (return code=0) completes.  Since the option values besides *'all'* are sufficiently explained by ```--help```, no further explaination will be provided for them.  However, *'all'* warrants mention.

*'all'* short circuits ```didx```'s typical execution flow replacing it with behavior to search and destroy dind server and client containers.  The search scours the local repository for container instances whose names regex match the naming pattern used by ```didx``` to identify candidate instances for deletion.  *'all'* then further filters the candidate instances to ensure their Docker [ENTRYPOINT](https://docs.docker.com/engine/reference/builder/#entrypoint) signatures reflect those assigned to the dind server and client containers.  A [```docker stop```](https://docs.docker.com/engine/reference/commandline/stop/) is executed for containers satisfying both filters before being destroyed by [```docker rm -v```](https://docs.docker.com/engine/reference/commandline/rm/).

Use ```--clean=all``` to rid the local repository of dind server and client containers that survived prior ```didx``` invocations but are no longer needed.  For example, a failure while running COMMAND ```test.sh``` invoked by: ```didx --clean=success --cp ./test.sh:/ /test.sh``` exits leaving both the dind server and client containers running.  After  debugging ```/test.sh```'s failure, the invocation of ```didx --clean=all``` will terminate and destroy these recently started dind containers, as well as any other leftover dind containers, started by ```didx```, known to the Docker Engine Host.

####--storage-driver
The dind server creates a repository as an anynomous volume bound inside its container and isolated from the Docker Engine Host repository. ```--storage-driver``` option determines the file system/volume manager type employed by dind server to maintain its Docker repository.  The selection of this value can reflect the constraints imposed by the file system or volume manager type implemented for the Docker Engine Host and the desire to control, at a physical level, the representation of image layers.  Docker provides guidance selecting among its offered [storage driver types](https://docs.docker.com/engine/userguide/storagedriver/selectadriver/), as well as describing how [image layering operates](https://docs.docker.com/engine/userguide/storagedriver/imagesandcontainers/) which may also affect the storage driver decision.

```didx``` by default configures the dind server ```--storage-driver``` value to reflect the one employed by the Docker Engine Host.  Use ```didx```'s ```--help``` option to display this value.  This convention aligns with aim of ```didx```: to offer a test environment within the Docker Engine Host, therefore, the dind server container inherits its ```--storage-driver``` value from its Docker Engine Host.  To circumvent this scheme, use ```--storage-driver``` to specify the desired type.

####--cv-env
Specifies an environment variable name assigned the Docker container name of the dind client container.  Use this option to change the variable name from ```DIND_CLIENT_NAME``` to the desired one.  Although its use is unlikely, this option supports the custom encoding of the ```docker exec [OPTIONS] CONTAINER``` that must prefix every ```didx``` COMMAND argument.  A custom form of ```docker exec...``` is necessary in situations when the "default prefix", explained below, doesn't specify the ```docker exec``` option values necessary to execute its command portion.  For example, if a command portion relied on user permissions different from root, a custom ```docker exec --user=1000:1000 $DIND_CLIENT_NAME...``` would need to be encoded to override the default prefix.

Each COMMAND encoded to execute within the dind client container must begin with some flavor of ```docker exec [OPTIONS] CONTAINER...```.  When the Docker Engine Host runs this command, it removes the ```docker exec [OPTIONS] CONTAINER``` prefix and then forwards the command portion to the dind container for execution.  If this forwarded command wishes to invoke a docker command requiring a response from the dind server, the forwarded command must begin ```docker [OPTIONS] COMMAND```.  For example, to list all the images known to the dind server the implemented command would appear as: ```'docker exec <DIND_CLIENT_NAME> docker images -a'```.

To avoid finger cramps resulting from typing the entire prefix for every COMMAND, ```didx``` and the Docker provided dind client container ENTRYPOINT [```"docker-entrypoint.sh"```](https://github.com/docker-library/docker/blob/99287145029122cf49321fa2a055d14240001d1d/1.11/docker-entrypoint.sh) each contribute a portion of the prefix to construct a complete "default prefix".  ```didx``` will prepend ```docker exec <DIND_CLIENT_NAME> docker-entrypoint.sh``` to the COMMAND when COMMAND begins with tokens other than ```docker exec```.  After forming the cmplete command, ```didx``` then executes it causing Docker Engine Host to process the prepared command: ```docker exec <DIND_CLIENT_NAME> docker-entrypoint.sh <COMMAND>``` by forwarding the ```docker-entrypoint.sh <COMMAND>``` portion to the running dind client container for execution.  Once started in the dind client container ```docker-entrypoint.sh``` processes the ```<COMMAND>``` through a filter that attempts to determine the ```<COMMAND>```'s type. 

```docker-entrypoint.sh``` recognizes three ```<COMMAND>``` types: 
*  a Docker command, like ```run ...```,
*  a Docker command beginning with a Docker Engine option, like ```-D images```,
*  and everything else (non-docker related)
For the first two types ```docker-entrypoint.sh``` will affix ```docker``` to the ```<COMMAND>``` string before executing ```<COMMAND>``` while for the third type ```docker-entrypoint.sh``` invokes ```<COMMAND>``` without affecting it.

In addition to automatically prefixing Docker related commands, ```docker-entrypoint.sh``` establishes the value of the DOCKER_HOST environment variable for itself and its child processes.  This behavior is critical to the successful execution of scripts invoked by COMMAND containing Docker commands, like ```docker build ...``` for without it, Docker commands will fail with messages indicating an inability to connect to the dind server.

For example, when given the COMMAND ```'images -a'``` as an argument, ```didx``` generates the prefix ```docker exec <DIND_CLIENT_NAME> docker-entrypoint.sh``` and then concantenates the COMMAND ```images -a``` to it forming:   ```'docker exec <DIND_CLIENT_NAME> docker-entrypoint.sh images a'```.  This generated command is then executed by the Docker Engine Host which removes ```docker exec <DIND_CLIENT_NAME>``` and forwards the command portion ```docker-entrypoint.sh images a'``` to the dind client container.
##Examples
```
#Ex 1 - start the latest version of the dind server & client and run them in the background
dockerHost:didx 
Inform: dind server named: 'dind_22789_server_latest' successfully started.
Inform: dind client named: 'dind_22789_client_latest' successfully started.
Inform: dind server named: 'dind_22789_server_latest' remains running.
Inform: dind client named: 'dind_22789_client_latest' remains running.

#Ex 2 - start dind server version 1.10 & dind client 1.9 and run them in the background
dockerHost:didx --sv 1.10 --cv 1.9
Inform: dind server named: 'dind_23563_server_1.10' successfully started.
Inform: dind client named: 'dind_23563_client_1.9' successfully started.
Inform: dind server named: 'dind_23563_server_1.10' remains running.
Inform: dind client named: 'dind_23563_client_1.9' remains running.

#Ex 2.1 - attach to the client and run 'docker version'
dockerHost:docker attach dind_23563_client_1.9
/ # docker version
Client:
 Version:      1.9.1
 API version:  1.21
 Go version:   go1.4.3
 Git commit:   a34a1d5
 Built:        Fri Nov 20 17:56:04 UTC 2015
 OS/Arch:      linux/amd64

Server:
 Version:      1.10.3
 API version:  1.22
 Go version:   go1.5.3
 Git commit:   20f81dd
 Built:        2016-03-10T21:49:11.235199091+00:00
 OS/Arch:      linux/amd64
/ # 

#Ex 3 - Terminate & destroy the dind servers and clients initiated by Ex 1 & Ex 2
dockerHost:didx./didx.sh --clean all
Inform: dind client named: 'dind_23563_client_1.9' terminated & destroyed.
Inform: dind server named: 'dind_23563_server_1.10' terminated & destroyed.
Inform: dind client named: 'dind_22789_client_latest' terminated & destroyed.
Inform: dind server named: 'dind_22789_server_latest' terminated & destroyed.

#Ex 4 - Run a series of commands to pull, report on, run, and stop an alpine
#       image via latest version of dind. Once complete remove the dind
#       server and client without regard to success/failure.
dockerHost:didx --clean anycase 'pull alpine' 'images' 'run -dit --name alpine_container alpine sh' 'ps' 'stop alpine_container' 
Inform: dind server named: 'dind_1118_server_latest' successfully started.
Inform: dind client named: 'dind_1118_client_latest' successfully started.
Using default tag: latest
latest: Pulling from library/alpine
e110a4a17941: Pulling fs layer
e110a4a17941: Verifying Checksum
e110a4a17941: Download complete
e110a4a17941: Pull complete
Digest: sha256:3dcdb92d7432d56604d4545cbd324b14e647b313626d99b889d0626de158f73a
Status: Downloaded newer image for alpine:latest
Inform: Command: 'docker exec dind_1118_client_latest docker-entrypoint.sh pull alpine' successfully terminated.
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
alpine              latest              4e38e38c8ce0        9 days ago          4.799 MB
Inform: Command: 'docker exec dind_1118_client_latest docker-entrypoint.sh images' successfully terminated.
7d64a075f70d8a4476024add123d2011154c261de47e8905f204bb7c3dbb3911
Inform: Command: 'docker exec dind_1118_client_latest docker-entrypoint.sh run -dit --name alpine_container alpine sh' successfully terminated.
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                  PORTS               NAMES
7d64a075f70d        alpine              "sh"                1 seconds ago       Up Less than a second                       alpine_container
Inform: Command: 'docker exec dind_1118_client_latest docker-entrypoint.sh ps' successfully terminated.
alpine_container
Inform: Command: 'docker exec dind_1118_client_latest docker-entrypoint.sh stop alpine_container' successfully terminated.
Inform: dind server named: 'dind_1118_server_latest' terminated & destroyed.
Inform: dind client named: 'dind_1118_client_latest' terminated & destroyed.

```

##Terms
**Docker Engine Host**<a id="TermsDockerEngineHost"></a> - refers to the Docker server instance that manages (runs, terminates) the dind server and associated client containers.

##Warning Label
The <a href="#TermsDockerEngineHost">Docker Engine Host</a> version can differ from the Docker Engine versions running in the dind server and client, however, version incompatibilities may arise when mixing certain groupings of differning versions.  In general, conflicts arise from differences in capability settings and they can sometimes be resolved.  View the following links for an indepth discussion of dind cautionary tales:

   + [~jpetazzo/Using Docker-in-Docker for your CI or testing environment? Think twice.](http://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/)
   + [Original dind project](https://github.com/jpetazzo/dind#docker-in-docker)
