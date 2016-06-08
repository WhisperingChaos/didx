###############################################################################
##
##
##  Purpose:
##    Define trap processing. Traps will destroy the server and client when
##    an unexpected failure occurs.
##
###############################################################################
declare TRAP_SERVER_NAME
declare TRAP_CLIENT_NAME
trap_server_Destroy(){
  server_Destroy "$TRAP_SERVER_NAME"
}
trap_server_destroy_Set(){
  TRAP_SERVER_NAME="$1"
  trap 'trap_server_Destroy' EXIT
}
trap_server_client_Destroy(){
  client_Destroy "$TRAP_CLIENT_NAME"
  server_Destroy "$TRAP_SERVER_NAME" 
}
trap_server_client_destroy_Set(){
  TRAP_SERVER_NAME="$1"
  TRAP_CLIENT_NAME="$2"
  trap 'trap_server_client_Destroy' EXIT
}
trap_Off(){
  trap - EXIT
}
###########################################################################
##
##  Purpose:
##    Assign simple, single valued bash variable references a value.
##
##  Input:
##    $1 - Variable name to a single valued bash variable.
##    $2 - The value to assign to this variable.
##
##  Output:
##    $1 - Variable assigned value provided by $2.
##
###########################################################################
ref_simple_value_Set(){
  eval $1=\"\$2\"
}
###########################################################################
##
##  Purpose:
##    Obtain the storage driver used by the docker instance that will
##    execute this script's docker commands.
##
##  Input:
##    $1 - Variable name to accept the storage driver name.
##
##  Output:
##    $1 - Variable assigned the storage driver name displayed by 'docker info.'
##
###########################################################################
docker_stg_driver_Get(){
  local -r stgDrvr_ref="$1"
  local -r NameRegex='[a-zA-Z0-9][a-zA-Z0-9_.-]*'

  if ! [[ $( docker info 2>/dev/null ) =~ Storage.Driver:[[:space:]]*($NameRegex) ]]; then
    ScriptUnwind "$LINENO" "Unable to identify 'Storage Driver:' value from 'docker info' command."
  fi
  ref_simple_value_Set "$stgDrvr_ref" "${BASH_REMATCH[1]}" 
}
##############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdArgumentsParse
##
##    Override usual implementation to define repeatable option:
##     --cp.
##
###############################################################################
function VirtCmmdArgumentsParse () {
  local -r -a ucpOptRepeatList=( '--cp' '--mt' )
  ArgumentsParse "$1" "$2" "$3" 'ucpOptRepeatList'
}
##############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdConfigSetDefault
##
##    Override usual implementation to define repeatable option:
##     --cp.
##
###############################################################################
VirtCmmdConfigSetDefault(){
DOCKER_LOCAL_REPRO_PATH='/var/lib/docker'
#TODO refactor the following regex into own module.
REG_EX_REPOSITORY_NAME_UUID='^([a-z0-9]([._-]?[a-z0-9]+)*/)*(sha256:)?[a-z0-9]([a-z0-9._-]+)*(:[A-Za-z0-9._-]*)?'
REG_EX_CONTAINER_NAME_UUID='^[a-zA-Z0-9][a-zA-Z0-9_.-]*'
STATUS_TERM_DSTRY='terminated & destroyed'
true
}
##############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdHelpDisplay
##
###############################################################################
VirtCmmdHelpDisplay(){
  local stgDrvrDefault
  docker_stg_driver_Get 'stgDrvrDefault'
  local -r stgDrvrDefault

cat <<HELP_DOC

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
                                 stable (public) Docker Engine version.
    --cv                       Docker client version.  Defaults to --sv value.
    --cp[]                     Copy files from source location into container running 
                                 Docker client. (Optional)  
                                 Format: <SourceSpec>:<AbsoluteClientContainerPath>
                                 'docker cp' used when SourceSpec referrs to host file or
                                 input stream.  Otherwise, when source refers to 
                                 container or image, cp performed by 'dkrcp'.
    -p,--pull=false            Perform explicit docker pull before running server/client.
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
                                 anycase: Reguardless of COMMAND exit code, terminate
                                          and remove server, client containers.
                                          Delete server data volume.
                                 all:     Remove all dind containers from local repository.
                                          If necessary, terminate running instances.
    -s,--storage-driver=$stgDrvrDefault  Docker storage driver name.  Determines method
                                  applied to physically represent and manage images and
                                  containers stored locally by the Docker server container.
                                  Value defaults to the one utilized by the Docker instance
                                  managing the Docker server container.  
    --cv_env=CLIENT_NAME       Environment variable name which contains the Docker client's
                                 container name.  Use in COMMAND to identify client container.
    -h,--help=false            Don't display this help message.
    --version=false            Don't display version info.

For more help: https://github.com/WhisperingChaos/didx/blob/master/README.md#didx

HELP_DOC
}
##############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdVersionDisplay
##
###############################################################################
VirtCmmdVersionDisplay(){
cat <<VERSION_DOC

Version : 0.5
Requires: bash 4.0+, Docker Client
Issues  : https://github.com/WhisperingChaos/dkind/issues
License : The MIT License (MIT) Copyright (c) 2016 Richard Moyse License@Moyse.US

VERSION_DOC
}
###############################################################################
##
##  Purpose:
##    see VirtCmmdInterface.sh -> VirtCmmdOptionsArgsDef
##
###############################################################################
VirtCmmdOptionsArgsDef(){

  local stgDrvrDefault
  docker_stg_driver_Get 'stgDrvrDefault'
  local -r stgDrvrDefault
# optArgName cardinality default verifyFunction presence alias
cat <<OPTIONARGS
ArgN             single ''                ''                                              optional
--sv	         single 'latest'          ''                                              required
--cv             single ''                ''                                              optional
--pull           single false=EXIST=true  "OptionsArgsBooleanVerify '\\<--pull\\>'"       required "-p"
--storage-driver single '$stgDrvrDefault' ''                                              required "-s" 
--cv_env         single 'CLIENT_NAME'     "option_envName_Verify    '\\<--cv_env\\>'"     required
--cp=N           single ''                "option_cp_format_Verify  '\\<--cp=N\\>'"       optional
--mt=N           single ''                "option_mt_format_Verify  '\\<--mt=N\\>'"       optional
--clean          single 'none'            "option_clean_Verify      '\\<--clean\\>'"      required
--help           single false=EXIST=true  "OptionsArgsBooleanVerify '\\<--help\\>'"       required "-h"
--version        single false=EXIST=true  "OptionsArgsBooleanVerify '\\<--version\\>'"    required
OPTIONARGS
}
###############################################################################
##
##  Purpose:
##    Verify environment variable name conforms to Bash standard.
##
##  Inputs:
##    $1 - Bash environment variable name.
## 
##  Return Code:
##    When Success:
##       Nothing.     
##    When Failure: 
##      Write error reason to STDERR.
##
###############################################################################
option_envName_Verify(){
  local -r envName="$1"

  local -r envNameDef='^[a-zA-Z_]+[a-zA-Z0-9_]*$'
  if ! [[ $envName =~ $envNameDef ]]; then
    ScriptError "Environment name: '$envName' must conform to: '$envNameDef'."
  fi
}
###############################################################################
##
##  Purpose:
##    Verify target-source specification for cp.
##
##  Inputs:
##    $1 - target-source specification.
## 
##  Return Code:
##    When Success:
##       Nothing.     
##    When Failure: 
##      Write error reason to STDERR.
##
###############################################################################
option_cp_format_Verify(){
  local srcSpec
  local trgSpec
  cp_srcTrg_Seperate "$1" 'srcSpec' 'trgSpec' 
}
###############################################################################
##
##  Purpose:
##    Verify target-source specification for mt.
##
##  Inputs:
##    $1 - target-source specification.
## 
##  Return Code:
##    When Success:
##       Nothing.     
##    When Failure: 
##      Write error reason to STDERR.
##
###############################################################################
option_mt_format_Verify(){
  if ! [[ $1 =~ ^(.+):(/.+) ]]; then
    ScriptError "Mount source-target spec: '$1' must encode a ':' immediately before its absolute target container path. Ex: './hostfile:/targetContainerLoc'."
  fi
}
###############################################################################
##
##  Purpose:
##    Verify --clean option values.
##    
##  Inputs:
##    $1 - Clean option value.
## 
##  Return Code:
##    When Success:
##       Nothing.     
##    When Failure: 
##      Write error message to STDERR and exit.
##
###############################################################################
option_clean_Verify(){
  case $1 in
    none|success|failure|anycase|all) 
      true
    ;;
    *)
      ScriptError "Expected --clean values: 'none|success|failure|anycase|all', encountered: '$1'."
    ;;
  esac
}
###############################################################################
##
##  Purpose:
##    Start Docker Engine server and client containers.  Run specified
##    commands in context of client container.  Determine exit status and
##    clean up according to --clean option.
##
##  Input:
##    $1 - Variable name representing the array of all options 
##         and arguments names in the order encountered on the command line.
##    $2 - Variable name representing an associative map of all
##         option and argument values keyed by the option/argument names.
##
###############################################################################
VirtCmmdExecute(){
  local -r optArgLst_ref="$1"
  local -r optArgMap_ref="$2"
  # clean all directive short circuits general functionality
  local cleanDirective
  AssociativeMapAssignIndirect "$optArgMap_ref" '--clean' 'cleanDirective'
  local -r cleanDirective
  if [ "$cleanDirective" == 'all' ]; then
    server_client_Iterate 'all' 'server_or_client_Destroy "$containerType" "$containerName"'
    # terminate script
    return
  fi
  # obtain server version
  local serverVersion
  AssociativeMapAssignIndirect "$optArgMap_ref" '--sv' 'serverVersion'
  if [ "$serverVersion" == 'latest' ]; then
    local -r stag="dind"
  else
    local -r stag="${serverVersion}-dind"
  fi
  # obtain server storage driver
  local storageDriver
  AssociativeMapAssignIndirect "$optArgMap_ref" '--storage-driver' 'storageDriver'
  local -r storageDriver
  # start the docker server
  local -r serverName="dind_$$_server_${serverVersion}"
  # need to pull fresh server and client
  local dockerPull
  AssociativeMapAssignIndirect "$optArgMap_ref" '--pull' 'dockerPull'
  local -r dockerPull
  if $dockerPull; then
    if ! docker pull docker:$stag >/dev/null; then
      ScriptUnwind "$LINENO" "Failed to pull Docker server image: 'docker:$stag'."
    fi
  fi
  if ! docker run --privileged -d --name $serverName -v "$DOCKER_LOCAL_REPRO_PATH" docker:$stag /usr/local/bin/dockerd-entrypoint.sh --storage-driver=$storageDriver >/dev/null; then
    ScriptUnwind "$LINENO" "Failed to start Docker server from image: 'docker:$stag', with container name: '$serverName'."
  fi
  # set trap to destroy when something unexpected happens.
  trap_server_destroy_Set "$serverName"
  # generate mount, -v, options if specified.
  local -r mtOptFilter='[[ $optArg =~ ^--mt=[1-9][0-9]*$ ]]'
  local -a mtOptLst
  local -A mtOptMap
  if ! OptionsArgsFilter "$optArgLst_ref" "$optArgMap_ref" 'mtOptLst' 'mtOptMap' "$mtOptFilter" 'true'; then
    ScriptUnwind "$LINENO" "Problem filtering mt options."
  fi
  local mtClientOpts
  mt_options_Gen 'mtOptLst' 'mtOptMap' 'mtClientOpts'
  local -r mtClientOpts
  # determine client tag
  local ctag
  AssociativeMapAssignIndirect "$optArgMap_ref" '--cv' 'ctag'
  if [ -z "$ctag" ]; then ctag="$serverVersion"; fi
  local -r ctag
  if $dockerPull; then 
    if ! docker pull docker:$ctag >/dev/null; then
      ScriptUnwind "$LINENO" "Failed to pull Docker client image: 'docker:$ctag'."
    fi
  fi
  # start Docker client
  local -r clientName="dind_$$_client_${ctag}"
  if ! eval docker run \-d \-i \-t $mtClientOpts \-\-name \$clientName \-\-link \$\{serverName\}:docker docker:\$ctag >/dev/null; then
    ScriptUnwind "$LINENO" "Failed to start Docker client from image: 'docker:$ctag', with container name: '$clientName'."
  fi
  server_client_report "$serverName" "$clientName" 'successfully started'
  # set trap to destroy both server and client when something unexpected happens.
  trap_server_client_destroy_Set "$serverName" "$clientName"
  # establish value for environment variable referenced by COMMANDs that
  # will resolve to Docker client container name.
  local clientName_ref
  AssociativeMapAssignIndirect "$optArgMap_ref" '--cv_env' 'clientName_ref'
  local -r clientName_ref
  ref_simple_value_Set "$clientName_ref" "$clientName"
  # create cp argument map by filtering cli options.
  local -r cpOptFilter='[[ $optArg =~ ^--cp=[1-9][0-9]*$ ]]'
  local -a cpOptLst
  local -A cpOptMap
  if ! OptionsArgsFilter "$optArgLst_ref" "$optArgMap_ref" 'cpOptLst' 'cpOptMap' "$cpOptFilter" 'true'; then
    ScriptUnwind "$LINENO" "Problem filtering cp arguments."
  fi
  # perform cp operation before executing commands as the files may represent 
  # scripts that will be executed in context of Docker client.
  cp_Perform 'cpOptLst' 'cpOptMap' "$clientName"
  # create command map by filtering cli arguments.
  local -r cmmdArgFilter='[[ $optArg =~ ^Arg[1-9][0-9]*$ ]]'
  local -a cmmdArgLst
  local -A cmmdArgMap
  if ! OptionsArgsFilter "$optArgLst_ref" "$optArgMap_ref" 'cmmdArgLst' 'cmmdArgMap' "$cmmdArgFilter" 'true'; then
    ScriptUnwind "$LINENO" "Problem filtering command arguments."
  fi
  command_Execute 'cmmdArgLst' 'cmmdArgMap' "$clientName_ref"
  local -r rtn_code="$?"
  # eliminate trap
  trap_Off
  server_client_Clean "$serverName" "$clientName" "$cleanDirective" "$rtn_code"
  # exit with the return code of the last COMMAND 
  return $rtn_code
}
###########################################################################
##
##  Purpose:
##    Generate docker host volume option.
##
##  Input:
##    $1  - Array variable name of ordered mt keys.
##    $2  - Map variable name of mt keys specified in $1 associated 
##          to host-target container specification.
##    $3  - Variable name to assign generated docker run -v option syntax.
##
###########################################################################
mt_options_Gen(){
  local -r mtOptLst_ref="$1"
  local -r mtOptMap_ref="$2"
  local -r mtClientOpts_ref="$3"

  local mtPath
  local mtPathComplete
  eval set -- \$\{$mtOptLst_ref\[\@\]\}
  while (( $# > 0 )); do
    AssociativeMapAssignIndirect "$mtOptMap_ref" "$1" 'mtPath'
    mtPathComplete+="-v '$mtPath' "
    shift
  done
  ref_simple_value_Set "$mtClientOpts_ref" "$mtPathComplete"
}  
###########################################################################
##
##  Purpose:
##    Copy one or more files/directories from some source, like host file
##    system, to container running the Docker client.
##
##  Input:
##    $1  - List of ordered cp keys.
##    $2  - Map of cp keys specified in $1 associated to source-target
##          specification.
##    $3  - Container name assigned to the Docker client.
##
###########################################################################
cp_Perform(){
  local -r cpOptLst_ref="$1"
  local -r cpOptMap_ref="$2"
  local -r clientName="$3"

  local sourceTargetSpec
  local srcSpec
  local trgSpec
  local srcSpecType
  local dkrcpExist='false'
  local dkrcpName
  if dkrcp_Exist 'dkrcpName'; then dkrcpExist='true'; fi
  local -r dkrcpName
  local -r dkrcpExist
  eval set -- \$\{$cpOptLst_ref\[\@\]\}
  while (( $# > 0 )); do
    AssociativeMapAssignIndirect "$cpOptMap_ref" "$1" 'sourceTargetSpec'
    cp_srcTrg_Seperate "$sourceTargetSpec" 'srcSpec' 'trgSpec'
    if ! arg_type_format_decide "$srcSpec" 'srcSpecType'; then
      ScriptUnwind "$LINENO" "Copy source: '$srcSpec' of unknown type."
    fi
    case $srcSpecType in
      filepath|stream)
        if ! docker cp "$srcSpec" "${clientName}:$trgSpec">/dev/null; then
          ScriptUnwind "$LINENO" "Copy command failed: 'docker cp $srcSpec ${clientName}:$trgSpec'."
        fi
      ;;
      containerfilepath|imagefilepath)
        if ! dkrcpExist; then
          ScriptUnwind "$LINENO" "Source type: '$srcSpecType' for source spec: '$srcSpec' requires: 'dkrcp.sh'."
        elif ! $dkrcpName "$srcSpecType" "${clientName}:$trgSpec"; then
          ScriptUnwind "$LINENO" "Copy command failed: 'dkrcp $srcSpec ${clientName}:$trgSpec'."
        fi
      ;;
      *)
        ScriptUnwind "$LINENO" "Copy source: '$srcSpec' doesn't exist or of unknown type: '$srcSpecType'."
      ;;
    esac
    shift
  done
}
###########################################################################
##
##  Purpose:
##    Determine if dkrcp exists and command name.
##
##  Input:
##    $1 - Variable name to return command name.
##    
##  Output:
##    When success:
##      $1  - Reflects name of dkrcp command.
##
###########################################################################
dkrcp_Exist(){
  local dkrcpNm_ref="$1"

  if   dkrcp    --version 2>/dev/null | grep 'Moyse'>/dev/null; then
    ref_simple_value_Set "$dkrcpNm_ref" 'dkrcp'
  elif dkrcp.sh --version 2>/dev/null | grep 'Moyse'>/dev/null; then
    ref_simple_value_Set "$dkrcpNm_ref" 'dkrcp.sh'
  else false
  fi
}
###########################################################################
##
##  Purpose:
##    Extract source and target argument specifiers for copy operation.
##
##  Input:
##    $1  - Source-Target specification. Source cp reference separated
##          from Target absolute path by colon (':').  Source part
##          could reference files with host file, container, or image.
##    $2  - Variable name to return source spec part.
##    $3  - Variable name to return target spec part.
##
##  Output:
##    When success:
##      $2  - updated to reflect 
##      STDERR - Abort message due to improper format of Source-Target specification.
##               not redirected.
##
###########################################################################
cp_srcTrg_Seperate(){
  local -r srcTrgSpec="$1"
  local -r srcSpec_ref="$2"
  local -r trgSpec_ref="$3"

  # seperate source spec from target.  Rely on regex greediness to include
  # container, image reference in source part even when they include :/ 
  if ! [[ $srcTrgSpec =~ ^(.+):(/.+) ]]; then
    ScriptUnwind "$LINENO" "Copy source-target spec: '$srcTrgSpec' must encode a ':' immediately before its absolute target path. Ex: './hostfile:/targetLoc'."
  fi
  ref_simple_value_Set "$srcSpec_ref" "${BASH_REMATCH[1]}"
  ref_simple_value_Set "$trgSpec_ref" "${BASH_REMATCH[2]}"
}
##############################################################################
#TODO refactor the fuction into own module.
##
##  Purpose:
##    Determine the argument type by examining its format.
##
##  Input:
##    $1 - A SOURCE or TARGET command line argument.
##    $2 - A variable name to return the decided type.
##    
##  Output:
##    When Success:
##    $2 Reference assigned the decided type:
##      'stream', 'imagefilepath', 'containerimagefilepath', or 'filepath'.
##
###############################################################################
arg_type_format_decide() {
  local -r arg="$1"
  local -r typeName_ref="$2"

  while true; do
    if [ "$arg" == '-' ]; then
      typeName='stream'
      break
    fi
    if [ "${arg:0:1}" == '/' ] || [ "${arg:0:1}" == '.' ]; then 
      typeName='filepath'
      break
    fi
    if [[ $arg =~ ${REG_EX_REPOSITORY_NAME_UUID}::.*$ ]]; then
      typeName='imagefilepath'
      break
    fi
    if [[ $arg =~ ${REG_EX_CONTAINER_NAME_UUID}:.*$ ]]; then 
      typeName='containerfilepath'
      break
    fi
    if [ -n "$arg" ]; then 
      typeName='filepath'
      break
    fi
    return 1
  done
  eval $typeName_ref\=\"\$typeName\"
}
###########################################################################
##
##  Purpose:
##    Execute one or more commands within the context of the Docker
##    client.
##
##  Input:
##    $1  - List of keys identifying COMMANDs in order specified by the 
##          command line.
##    $2  - Map of keys specified in $1, and their associated values.
##
##  Output:
##    STDOUT - Message indicating status of Docker server and client.  Will
##             also include messages generated by the COMMAND if not
##             redirected.
##    STDERR - Messages can include messages generated by the COMMMAND if
##             not redirected.
##
##  Return code set to first failed command or last succcessful one.
##
###########################################################################
command_Execute(){
  local -r cmdArgLst_ref="$1"
  local -r cmdArgMap_ref="$2"
  local -r clientName_ref="$3"

  # make selected variable name client name visible
  eval local \-r clientName=\"\$$clientName_ref\"
  local cmdTmplt
  local cmdExec
  local cmdRtnCd=0
  eval set -- \$\{$cmdArgLst_ref\[\@\]\}
  while (( $# > 0 )); do
    AssociativeMapAssignIndirect "$cmdArgMap_ref" "$1" 'cmdTmplt'
    eval local cmdExec=\"$cmdTmplt\"
    if ! [[ $cmdExec =~ ^[[:space:]]*docker[[:space:]]+exec ]]; then
      # ensure all commands begin with docker exec.  If not
      # user relies on script to add it with default exec option values.
      cmdExec="docker exec $clientName docker-entrypoint.sh $cmdExec"
    fi
    if $cmdExec; then
      ScriptInform "Command: '$cmdExec' successfully terminated."
    else
      cmdRtnCd="$?"
      ScriptError  "Command: '$cmdExec' failed with exit code: '$cmdRtnCd'. Terminating remaining commands."
      break
    fi
    shift
  done
  return $cmdRtnCd
}
###########################################################################
##
##  Purpose:
##    When directed, destroy the Docker server and associated client.
##
##  Input:
##    $1  - Container name for dind server. 
##    $2  - Container name for client linked to dind server. 
##    $3  - Clean option value directing behavior after executing COMMANDs
##    $4  - Last executed COMMAND return code.
##
##  Output:
##    STDOUT - Message indicating status of Docker server and client.
##
###########################################################################
server_client_Clean(){
  local -r serverName="$1" 
  local -r clientName="$2" 
  local -r cleanDirective="$3"
  local -r cmmdRtnCode="$4"

  local remainsRunning='true'
  case $cleanDirective in
    none)       
      true
    ;;
    success)
      if [ "$cmmdRtnCode" -eq '0' ]; then
        server_client_Destroy "$serverName" "$clientName" \
        && remainsRunning='false'
      fi
    ;;
    failure)
      if [ "$cmmdRtnCode" -ne '0' ]; then
        server_client_Destroy "$serverName" "$clientName" \
        && remainsRunning='false'
      fi
    ;;
    anycase)
      server_client_Destroy "$serverName" "$clientName" \
      && remainsRunning='false'
    ;;
    *)
      ScriptError "Unknown clean directive: '$cleanDirective'."
    ;;
  esac
  local status="$STATUS_TERM_DSTRY"
  if $remainsRunning; then
    status='remains running'
  fi
  server_client_report "$serverName" "$clientName" "$status"
  true
}
###########################################################################
##
##  Purpose:
##    Iterate over all containers whose name conforms to script generated
##    dind server or client name and implements dind entry point name of 
##    dockerd-entrypoint.sh.
##
##    Iterater terminates on first failure or all successful.
##
##  Input:
##    $1  - A filter pattern to select a subset or a proper superset
##          of dind containers.  Currently, 'all' simply selects every
##          dind container.  
##    $2  - A function invocation whose parameters reverence
##          '$containerType' and '$containerName'
##
###########################################################################
server_client_Iterate(){
  local -r pattern="$1"  # currently ignored
  local -r funExec="$2"
  local -r dindpatternClient='dind_[0-9]+_client_([0-9.]+|latest)'
  local -r dindpatternServer='dind_[0-9]+_server_([0-9.]+-dind|latest)'

  local containerType
  local containerName
  local entryPoint
  local rtnStatus=0
  while [ "$rtnStatus" -eq '0' ] && read -r containerName; do
    if   [[ $containerName =~ ($dindpatternClient) ]]; then
      containerType='client'
      entryPoint='.*docker-entrypoint.sh'
    elif [[ $containerName =~ ($dindpatternServer) ]]; then   
      containerType='server'
      entryPoint='.*dockerd-entrypoint.sh'
    else
      # container name fails to match dind name generated by this script
      continue
    fi
    containerName="${BASH_REMATCH[1]}"
    if [[ $( docker inspect -f '{{ .Config.Entrypoint }}' $containerName 2>/dev/null; ) =~ $entryPoint ]]; then
      # matches dind container pattern and entrypoint reflects dind signature
      # pretty confident that's a dind container generated by this script.
      eval $funExec;
      rtnStatus="$?"
    fi
  done < <( docker ps -a )
}
###########################################################################
##
##  Purpose:
##    Destroy dind client.
##
##  Input:
##    $1  - Container name for dind client. 
##
###########################################################################
client_Destroy(){
    docker    stop "$1" > /dev/null \
    && docker rm   "$1" > /dev/null 
}
###########################################################################
##
##  Purpose:
##    Destroy dind server and it's repository.
##
##  Input:
##    $1  - Container name for dind server. 
##
###########################################################################
server_Destroy(){
    docker    stop  "$1" > /dev/null \
    && docker rm -v "$1" > /dev/null 
}
###########################################################################
##
##  Purpose:
##    Destroy dind server or client.
##
##  Input:
##    $1  - Container type: 'client' or 'server'
##    $2  - Container name. 
##
###########################################################################
server_client_Destroy(){
  local -r serverName="$1" 
  local -r clientName="$2"

  client_Destroy "$clientName" && server_Destroy  "$serverName"
}
###########################################################################
##
##  Purpose:
##    Destroy dind server or client.
##
##  Input:
##    $1  - Container type: 'client' or 'server'
##    $2  - Container name. 
##
###########################################################################
server_or_client_Destroy(){
  local -r containerType="$1" 
  local -r containerName="$2"

  ${containerType}_Destroy "$containerName" \
  && dind_Report "${containerType}" "$containerName" "$STATUS_TERM_DSTRY"
}
###########################################################################
##
##  Purpose:
##    Generate status report to STDOUT regarding dind server/client status.
##
##  Input:
##    $1  - Container name for dind server. 
##    $2  - Container name for dind client linked to dind server. 
##    $3  - Container status.
##
##  Output:
##    STDOUT - status message.
##
###########################################################################
server_client_report(){
  local -r serverName="$1" 
  local -r clientName="$2"
  local -r status="$3" 

  dind_Report 'server' "$serverName" "$status"
  dind_Report 'client' "$clientName" "$status"
}
###########################################################################
dind_Report(){
  ScriptInform "dind $1 named: '$2' $3."
}
FunctionOverrideCommandGet
###############################################################################
# 
# The MIT License (MIT)
# Copyright (c) 2016 Richard Moyse License@Moyse.US
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
###############################################################################
#
# Docker and the Docker logo are trademarks or registered trademarks of Docker, Inc.
# in the United States and/or other countries. Docker, Inc. and other parties
# may also have trademark rights in other terms used herein.
#
###############################################################################
