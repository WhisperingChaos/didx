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
                                 'docker cp' used when SourceSpec referrs to host file or
                                 input stream.  Otherwise, when source refers to 
                                 container or image, cp performed by 'dkrcp'.
    --mt[]                     Mount host file system references into container running
                                 Docker client. (Optional)
                                 Format: <HostFilePath>:<AbsoluteClientContainerPath>
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
    -s,--storage-driver=aufs  Docker storage driver name.  Determines method
                                  applied to physically represent and manage images and
                                  containers stored locally by the Docker server container.
                                  Value defaults to the one utilized by the Docker instance
                                  managing the Docker server container.  
    --cv-env=CLIENT_NAME       Environment variable name which contains the Docker client's
                                 container name.  Use in COMMAND to identify client container.
    -h,--help=false            Don't display this help message.
    --version=false            Don't display version info.

For more help: https://github.com/WhisperingChaos/didx/blob/master/README.md#didx

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

*'all'* short circuits ```didx```'s typical execution flow replacing it with behavior to search and destroy dind server and client containers.  The searches scours the local repository for container instances whose names regex match the naming pattern used by ```didx``` to identify candidate instances for deletion.  *'all'* then further filters the candidate instances to ensure their Docker [entrypoint](https://docs.docker.com/engine/reference/builder/#entrypoint) signatures reflect those assigned to the dind server and client containers.  A [```docker stop```](https://docs.docker.com/engine/reference/commandline/stop/) is executed for containers satisfying both filters before being destroyed by [```docker rm -v```](https://docs.docker.com/engine/reference/commandline/rm/).

Use ```--clean=all``` to rid the local repository of dind server and client containers that survived prior ```didx``` invocations but are no longer needed.  For example, the execution of: ```didx --clean=success --cp ./test.sh:/ /test.sh``` exits leaving both the dind server and client containers running because ```/test.sh``` fails.  After  debugging ```/test.sh```'s failure the invocation of ```didx --clean=all``` will terminate and destroy the dind server and client containers.

####--storage-driver
The dind server creates a repository as an anynomous volume bound inside its container and isolated from the Docker Engine Host repository. ```--storage-driver``` option determines the file system type employed by dind server to maintain its Docker repository.  The selection of this value reflects the constraints imposed by the file system type implemented for the Docker Engine Host and the desire to control, at a physical level, the representation of image layers.  Docker provides guidance selecting amoungst its offered [storage driver types](https://docs.docker.com/engine/userguide/storagedriver/selectadriver/), as well as describing how [image layering operates](https://docs.docker.com/engine/userguide/storagedriver/imagesandcontainers/) which may also affect the storage driver decision.

```didx``` will by default configure the dind server ```--storage-driver``` value to reflect the one employed by the Docker Engine Host.  This default value is reflected by the help text displayed by ```--help```.  The rational behind this scheme derives from the primary aim of ```didx``` to present a test environment within the Docker Engine Host, therefore, the dind server container should inherit its ```--storage-driver``` value from its Docker Engine Host.  To circumvent this scheme, use ```--storage-driver``` to specify the desired type.

##Terms
**Docker Engine Host**<a id="TermsDockerEngineHost"></a> - refers to the Docker server instance that manages (runs, terminates) the dind server and associated client containers.

##Warning Label
The <a href="#TermsDockerEngineHost">Docker Engine Host</a> version can differ from the Docker Engine versions running in the dind server and client, however, version incompatibilities may arise when mixing certain groupings of differning versions.  In general, conflicts arise from differences in capability settings and they can sometimes be resolved.  View the following links for an indepth discussion of dind cautionary tales:

   + [~jpetazzo/Using Docker-in-Docker for your CI or testing environment? Think twice.](http://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/)
   + [Original dind project](https://github.com/jpetazzo/dind#docker-in-docker)
