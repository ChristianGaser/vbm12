#! /bin/sh

########################################################
# global parameters
########################################################
# $Id$

matlab=matlab   # you can use other matlab versions by changing the matlab parameter
defaults_file=""
LOGDIR=`PWD`
CPUINFO=/proc/cpuinfo
ARCH=`uname`
time=`date "+%Y%b%d_%H%M"`
NUMBER_OF_JOBS="";
nicelevel=0
shellcommand=
matlabcommand=
fg=

########################################################
# run main
########################################################

main ()
{
  parse_args ${1+"$@"}
  check_matlab
  check_files
  get_no_of_cpus
  run_vbm

  exit 0
}


########################################################
# check arguments and files
########################################################

parse_args ()
{
  local optname optarg
  count=0
  paras=

  if [ $# -lt 1 ]; then
    help
    exit 1
  fi
    
  while [ $# -gt 0 ]; do
    optname="`echo $1 | sed 's,=.*,,'`"
    optarg="`echo $2 | sed 's,^[^=]*=,,'`"
    paras="$paras $optname $optarg"
    case "$1" in
        --matlab* | -m*)
            exit_if_empty "$optname" "$optarg"
            matlab=$optarg
            shift
            ;;
        --defaults_file* | -d*)
            exit_if_empty "$optname" "$optarg"
            defaults_file=$optarg
            shift
            ;;
        --nprocesses* | -np*)
            exit_if_empty "$optname" "$optarg"
            NUMBER_OF_JOBS="-$optarg"
            shift
            ;;    
        --processes* | -p*)
            exit_if_empty "$optname" "$optarg"
            NUMBER_OF_JOBS=$optarg
            shift
            ;;
        --logdir* | -l*)
            exit_if_empty "$optname" "$optarg"
            LOGDIR=$optarg
            if [ ! -d $LOGDIR ]; then
              mkdir -p $LOGDIR
            fi
            shift
            ;;
        --n* | -n* | --nice* | -nice*)
            exit_if_empty "$optname" "$optarg"
            nicelevel=$optarg
            shift
            ;;
        --fg* | -fg*)
            exit_if_empty "$optname" "$optarg"
            fg=1
            ;;
        --f* | -f*)
            exit_if_empty "$optname" "$optarg"
            listfile=$optarg
            shift
            list=$(< $listfile);
            for F in $list; do
              ARRAY[$count]=$F
              ((count++))
              #echo $count
            done
            ;;
        --s* | -s* | --shell* | -shell*)
            exit_if_empty "$optname" "$optarg"
            shellcommand=$optarg
            shift
            ;;      
        --c* | -c* | --matlabcommand* | -matlabcommand*)
            exit_if_empty "$optname" "$optarg"
            matlabcommand=$optarg
            shift
            ;;      
        -h | --help | -v | --version | -V)
            help
            exit 1
            ;;
        -*)
            echo "`basename $0`: ERROR: Unrecognized option \"$1\"" >&2
            ;;
        *)
            ARRAY[$count]=$1
            ((count++))
            ;;
    esac
    shift
  done
}

########################################################
# check arguments
########################################################

exit_if_empty ()
{
  local desc val

  desc="$1"
  shift
  val="$*"

  if [ -z "$val" ]; then
    echo 'ERROR: No argument given with \"$desc\" command line argument!' >&2
    exit 1
  fi
}

########################################################
# check files
########################################################

check_files ()
{
  
  SIZE_OF_ARRAY="${#ARRAY[@]}"
  if [ "$SIZE_OF_ARRAY" -eq 0 ]; then
      echo 'ERROR: No files given!' >&2
      help
      exit 1
  fi

  i=0
  while [ "$i" -lt "$SIZE_OF_ARRAY" ]; do
    if [ ! -f "${ARRAY[$i]}" ]; then
      if [ ! -L "${ARRAY[$i]}" ]; then
        echo ERROR: File ${ARRAY[$i]} not found
        help
        exit 1
      fi
    fi
    ((i++))
  done

}

########################################################
# get # of cpus
########################################################
# modified code from
# PPSS, the Parallel Processing Shell Script
# 
# Copyright (c) 2009, Louwrentius
# All rights reserved.

get_no_of_cpus () {

  if [ "$ARCH" == "Linux" ]; then
    NUMBER_OF_PROC=`grep ^processor $CPUINFO | wc -l`
  elif [ "$ARCH" == "Darwin" ]; then
    NUMBER_OF_PROC=`sysctl -a hw | grep -w logicalcpu | awk '{ print $2 }'`
  elif [ "$ARCH" == "FreeBSD" ]; then
    NUMBER_OF_PROC=`sysctl hw.ncpu | awk '{ print $2 }'`
  else
    NUMBER_OF_PROC=`grep ^processor $CPUINFO | wc -l`
  fi
  
  if [ -z "$NUMBER_OF_PROC" ]; then
      echo "$FUNCNAME ERROR - number of CPUs not obtained. Use -p to define number of processes."
      exit 1
  fi

  # use all processors if not other defined
  if [ "$NUMBER_OF_JOBS" == "" ]; then
      NUMBER_OF_JOBS=$NUMBER_OF_PROC
  fi
  
  if [ $NUMBER_OF_JOBS -le -1 ]; then
    NUMBER_OF_JOBS=$(echo "$NUMBER_OF_PROC + $NUMBER_OF_JOBS" | bc)
    if [ "$NUMBER_OF_JOBS" -lt 1 ]; then
        NUMBER_OF_JOBS=1
    fi
  fi
  if [ "$NUMBER_OF_JOBS" -gt "$NUMBER_OF_PROC" ]; then
      NUMBER_OF_JOBS=$NUMBER_OF_PROC
  fi
  echo "Found $NUMBER_OF_PROC processors. Use $NUMBER_OF_JOBS."
  echo

}

########################################################
# run vbm tool
########################################################

run_vbm ()
{
    cwd=`dirname $0`
    pwd=$PWD
    
    # we have to go into the toolbox folder to find matlab files
    cd $cwd
    
    spm12=`dirname $cwd`
    spm12=`dirname $spm12`

    if [ "${LOGDIR}" == "" ]; then
        LOGDIR=`dirname ${ARRAY[0]}`
    fi
    
    export MATLABPATH=$spm12

    SIZE_OF_ARRAY="${#ARRAY[@]}"
    BLOCK=$((10000* $SIZE_OF_ARRAY / $NUMBER_OF_JOBS ))
   
    # argument empty?
    if [ ! "${defaults_file}" == "" ]; then
        # check wether absolute or relative names were given
        if [ ! -f ${defaults_file} -a -f ${pwd}/${defaults_file} ]; then
            defaults_file=${pwd}/${defaults_file}
        fi
    
        # check whether defaults file exist
        #if [ ! -f ${defaults_file} ];  then
        #    echo $defaults_file not found.
        #fi
    fi

    # split files and prepare tmp-file with filenames
    TMP=/tmp/vbm_$$
    i=0
    while [ "$i" -lt "$SIZE_OF_ARRAY" ]; do
        count=$((10000* $i / $BLOCK ))
        
        # check wether absolute or relative names were given
        if [ ! -f ${ARRAY[$i]} ];  then
            FILE=${pwd}/${ARRAY[$i]}
        else
            FILE=${ARRAY[$i]}
        fi
        if [ -z "${ARG_LIST[$count]}" ]; then
            ARG_LIST[$count]="$FILE"
        else
            ARG_LIST[$count]="${ARG_LIST[$count]} $FILE"
        fi
        echo ${FILE} >> ${TMP}${count}
        FDIR=$(dirname $FILE)
        ((i++))
    done
    
    vbmlog=${LOGDIR}/vbm_${HOSTNAME}_${time}
    
    i=0
    while [ "$i" -lt "$NUMBER_OF_JOBS" ]; do
        if [ ! "${ARG_LIST[$i]}" == "" ]; then
            j=$(($i+1))
            if [ -z "$matlabcommand" ]; then
              COMMAND="cg_vbm_batch('${TMP}${i}','${defaults_file}')"
            else
              CFILES=""
              for F in ${ARG_LIST[$i]} ; do 
                CFILES=$CFILES";"\'$F\';
              done
              CFILES=$(echo $CFILES | cut -c 2-);
              CFILES="{"$CFILES"}";
              matlabcommand2=$matlabcommand
              matlabcommand2=$(echo $matlabcommand2 |sed 's/CFILES/$CFILES/g');
              eval "COMMAND=\"$matlabcommand2\";" # fprintf('ERROR'); e=lasterror; e.message,
              COMMAND="try, spm; spm_get_defaults; cg_vbm_get_defaults; global defaults vbm matlabbatch; $COMMAND; catch vbmerr, sprintf('\n%s\nVBM Preprocessing error: %s:\n%s\n', repmat('-',1,72),vbmerr.identifier,vbmerr.message,repmat('-',1,72)); for si=1:numel(vbmerr.stack), vbm_io_cprintf('err',sprintf('%5d - %s\n',vbmerr.stack(si).line,vbmerr.stack(si).name)); end; vbm_io_cprintf('err',sprintf('%s\\n',repmat('-',1,72))); exit; end; fprintf('VBM batch processing done.'); exit;";
            fi
            SHCOMMAND="$shellcommand ${ARG_LIST[$i]}"          
                        
            echo Calculate
            for F in ${ARG_LIST[$i]}; do echo $F; done
            # File Output
            echo ---------------------------------- >> ${vbmlog}_${j}.log
            date                                    >> ${vbmlog}_${j}.log
            echo ---------------------------------- >> ${vbmlog}_${j}.log
            echo                                    >> ${vbmlog}_${j}.log
            echo Calling string of this batch:      >> ${vbmlog}_${j}.log
            echo "  $0 $paras"                      >> ${vbmlog}_${j}.log
            echo                                    >> ${vbmlog}_${j}.log
            echo MATLAB command of this batch:      >> ${vbmlog}_${j}.log
            echo "  $COMMAND"                       >> ${vbmlog}_${j}.log
            echo                                    >> ${vbmlog}_${j}.log
            echo Shell command of this batch:       >> ${vbmlog}_${j}.log
            echo "  $SHCOMMAND"                     >> ${vbmlog}_${j}.log
            echo                                    >> ${vbmlog}_${j}.log
            
            # check whether defaults exist
            if [ -f ${defaults_file} ];  then
              if [ -z "$shellcommand" ]; then
                # do nohup in background or not
                if [ -z "$fg" ]; then
                  nohup nice -n $nicelevel ${matlab} -nodisplay -nosplash -r "$COMMAND" >> ${vbmlog}_${j}.log 2>&1 &
                else
                  nohup nice -n $nicelevel ${matlab} -nodisplay -nosplash -r "$COMMAND" >> ${vbmlog}_${j}.log 2>&1
                fi
              else
                # do nohup in background or not
                if [ -z "$fg" ]; then
                  nohup nice -n $nicelevel $SHCOMMAND >> ${vbmlog}_${j}.log 2>&1 &
                else
                  nohup nice -n $nicelevel $SHCOMMAND >> ${vbmlog}_${j}.log 2>&1
                fi
              fi
              echo Check ${vbmlog}_${j}.log for logging information
              echo
            else
              echo Stop processing, because of missing default file: >> ${vbmlog}_${j}.log
              echo   ${defaults_file}  >> ${vbmlog}_${j}.log
            fi
        fi
        ((i++))
    done

    exit 0
}

########################################################
# check if matlab exist
########################################################

check_matlab ()
{
  found=`which ${matlab} 2>/dev/null`
  if [ ! -n "$found" ]; then
    echo $matlab not found.
    exit 1
  fi
}

########################################################
# help
########################################################

help ()
{
cat <<__EOM__

USAGE:
   cg_vbm_batch.sh filename|filepattern [-m matlab_command] [-w] [-p number_of_processes] [-d default_file] [-l log_folder]
   
   -n   nice level
   -m   matlab command (matlab version)
   -s   shell command to call other shell scripts (like FSL)
   -f   file with files to process
   -fg  do not run matlab process in background
   -p   number of parallel jobs (=number of processors)
   -np  set number of jobs by number_of_processors - number_of_processes
        (=number of free processors)
   -d   optional default file
   -l   directory for log-file
   -c   alternative matlab function that can be called such as the SANLM-filter
   
   Only one filename or pattern is allowed. This can be either a single file or a pattern
   with wildcards to process multiple files. Optionally you can set the matlab command 
   with the "-m" option and force to write already estimated segmentations with the "-w" option.

PURPOSE:
   Command line call of VBM12 segmentation

EXAMPLE
   cg_vbm_batch.sh spm/spm12/canonical/single_subj_T1.nii
   This command will process only the single file single_subj_T1.nii. 
   
   cg_vbm_batch.sh spm/spm12/canonical/single_subj_T1.nii -d your_vbm_defaults_file.m
   This command will process only the single file single_subj_T1.nii. The defaults defined
   in your_vbm_defaults_file.m will be used instead of cg_vbm_defaults.m.

   cg_vbm_batch.sh spm/spm12/canonical/*152*.nii
   Using wildcards all files containing the term "152" will be processed. In this case these 
   are the files avg152PD.nii, avg152T1.nii, and avg152T2.nii.

   cg_vbm_batch.sh spm/spm12/canonical/*152*.nii -m /usr/local/bin/matlab7
   Using wildcards all files containing the term "152" will be processed. In this case these 
   are the files avg152PD.nii, avg152T1.nii, and avg152T2.nii.
   As matlab-command /usr/local/bin/matlab7 will be used.
   
   cg_vbm_batch.sh -p 2 -c "vbm_vol_sanlm(CFILES,'sanlm_')" /Volumes/4TBWD/raw-cg/r[12][0-9][0-9][0-9]*.nii
   This command will call the SANLM-filter using the given files, that have to be indicated with CFILES
   as first argument. As prefix 'sanlm_' will be used.
   

INPUT:
   analyze or nifti files

OUTPUT:
   segmented images according to settings in cg_vbm_defaults.m
   ${LOGDIR}/vbm_${HOSTNAME}_${time}.log for log information

USED FUNCTIONS:
   cg_vbm_batch.m
   VBM12 toolbox
   SPM12

SETTINGS
   matlab command: $matlab
   
This script was written by Christian Gaser (christian.gaser@uni-jena.de).

__EOM__
}

########################################################
# call main program
########################################################

main ${1+"$@"}
