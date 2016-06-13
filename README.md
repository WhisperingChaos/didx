# didx
Configures and starts a 'Docker In Docker' (dind) server container with its own, empty local repository and spins up an associated docker client container.  Once dind server and client have started, '''didx''' executes one or more scripts/programs within context of the dind client container.

Use didx to create a Docker test environment that's automatically destroyed after all tests successfully complete.
#####ToC
[Options](#options)  
&nbsp;&nbsp;&nbsp;&nbsp;[--sv,--cv](#--sv--cv)  
&nbsp;&nbsp;&nbsp;&nbsp;[--pull](#--pull)  
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
  

##Options
####--sv,--cv
```--sv``` Determines the Docker Engine dind image version to run as the server container.  ```didx``` converts the version specifier to the appropriate dind tag.  The conversion simply appends *-dind* to the provided version specifier, except in the case of 'latest' which fetches the most recent dind version.  The  list of dind supported versions can be derived by removing the *-dind* suffix from [dind tags](https://hub.docker.com/r/library/docker/tags/).  

```--cv``` Determines the Docker client image to run as the client container (separate from the server).  When running, the client container is [linked](https://docs.docker.com/v1.8/userguide/dockerlinks/) to the dind server container.  Although the Docker client and server container versions are typically identical, they can differ.  If ```--cv``` is omitted, ```didx``` will match the client version to the one specified by ```--sv```.

####--pull
--pull directs ```didx``` to perform an explicit [```docker pull```](https://docs.docker.com/engine/reference/commandline/pull/) before executing ```docker run``` to potentially refresh the Docker Engine Host's local repository with the most recent version of both the dind server and client images. 

##Terms:
*Docker Engine Host* - refers to the Docker server instance that manages (runs, terminates) the dind server and associated client containers.

##Warning Label:
The Docker Engine Host version can differ from the Docker Engine versions running in the dind server and client, however, version incompatibilities may arise when mixing certain groupings of differning versions.  In general, conflicts arise from differences in capability settings and they can sometimes be resolved.  View the following links for an indepth discussion of dind cautionary tales:

   + [~jpetazzo/Using Docker-in-Docker for your CI or testing environment? Think twice.](http://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/)
   + [Original dind project](https://github.com/jpetazzo/dind)



[Docker Hub](https://hub.docker.com/_/docker/)
