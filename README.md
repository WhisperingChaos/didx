# didx
Configures and starts a 'Docker In Docker' (dind) server container with its own, empty local repository and spins up an associated docker client container.  Once dind server and client have started, '''didx''' executes one or more scripts/programs within context of the dind client container.

Use didx to create a Docker test environment that's automatically destroyed after all tests successfully complete.
#####ToC
[Options](#options)  
&nbsp;&nbsp;&nbsp;&nbsp;[--sv,--cv](#--sv--cv)  
&nbsp;&nbsp;&nbsp;&nbsp;[--pull](#--pull)  
&nbsp;&nbsp;&nbsp;&nbsp;[--pull](#--cp)  
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
    --cv_env=CLIENT_NAME       Environment variable name which contains the Docker client's
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

##Terms
**Docker Engine Host**<a id="TermsDockerEngineHost"></a> - refers to the Docker server instance that manages (runs, terminates) the dind server and associated client containers.

##Warning Label
The Docker Engine Host <a href="#TermsDockerEngineHost">Docker Engine Host</a> version can differ from the Docker Engine versions running in the dind server and client, however, version incompatibilities may arise when mixing certain groupings of differning versions.  In general, conflicts arise from differences in capability settings and they can sometimes be resolved.  View the following links for an indepth discussion of dind cautionary tales:

   + [~jpetazzo/Using Docker-in-Docker for your CI or testing environment? Think twice.](http://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/)
   + [Original dind project](https://github.com/jpetazzo/dind#docker-in-docker)
