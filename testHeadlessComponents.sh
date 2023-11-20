#!/bin/bash

set -x
set -e
set -o pipefail

## assumes that both directories with old and new rpms are provided and filled with relevant rpms
## this script attempts parallel installation of old and new set of rpms

## resolve folder of this script, following all symlinks,
## http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" && pwd )"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
readonly SCRIPT_DIR="$( cd -P "$( dirname "$SCRIPT_SOURCE" )" && pwd )"

# detecting platform
platform="$(uname)"
if [ "$platform" == "Linux" ]; then
    # Linux-specific code
    OS="linux"
elif [ "$platform" == "Darwin" ]; then
    # Mac-specific code
    OS="mac"
elif [ "${platform#"MINGW64_NT"}" != "$platform" ]; then
    # Windows (Cygwin) specific code
    OS="windows"
else
    echo "Unsupported platform"
    exit 1
fi

function unwrap_file_to_location() {
  if [ "$OS" == "mac" -o "$OS" == "linux" ]; then
    tar --strip-components=1 -xvf $1 -C $2
  elif [ "$OS" == "windows" ]; then
    unzip $1 -d $2
    # Get the name of the extracted folder (assuming only one folder is present)
    ls $2
    extracted_folder_name=$(ls $2)

    # Ensure only one folder is found
    if [ "$(ls $2 | wc -l)" -eq 1 ]; then
        # Move the contents to the desired destination without creating a new directory
        mv "$2/$extracted_folder_name"/* "$2"
    else
        echo "Error: More than one directory found in $2."
    fi
  fi
}

function installAlternativeJDK() {
  ARCH=$( uname -m )
  if [ "x$BOOTJDK_DIR" == "x" ]; then
    BOOTJDK_DIR=~/bootjdk
  fi
  if [ ! "x$ALTERNATE_BOOT_JDK" == "x" ] ; then
    ALTERNATIVE_JDK_DIR=$ALTERNATE_BOOT_JDK
    return 0
  fi
  if [ "x$BOOTJDK_ARCHIVE_DIR" == "x" ]; then
    BOOTJDK_ARCHIVE_DIR=$WORKSPACE/bootjdkarchive
    mkdir -p $BOOTJDK_ARCHIVE_DIR
    cd $BOOTJDK_ARCHIVE_DIR
    curl -OLJks "https://api.adoptopenjdk.net/v3/binary/latest/$OJDK_VERSION_NUMBER/ga/$OS/$ARCH/jdk/hotspot/normal/adoptopenjdk"
    rm -rf ${BOOTJDK_DIR}
    mkdir -p ${BOOTJDK_DIR}
    unwrap_file_to_location ${BOOTJDK_ARCHIVE_DIR}/* ${BOOTJDK_DIR}
  else
    rm -rf ${BOOTJDK_DIR}
    mkdir -p ${BOOTJDK_DIR}
    ls ${BOOTJDK_ARCHIVE_DIR}
    unwrap_file_to_location ${BOOTJDK_ARCHIVE_DIR}/*${ARCH}.tarxz ${BOOTJDK_DIR}
  fi
}

function run_java_with_headless {
  COMPONENTS_TO_TEST=$2
  java -cp $cp -Djava.awt.headless=$1 MainRunner -test=$COMPONENTS_TO_TEST -jreSdkHeadless=$JRESDK -displayValue=$DISPLAY
}

function run_swing_component_test_unset {
  TEST_ARGUMENT=$1
  TEST_BOOL=$2

  echo "---------------------------------------------------------------------"
  echo "use -Djava.awt.headless=$TEST_BOOL and unset display"
  echo "---------------------------------------------------------------------"
  unset DISPLAY
  run_java_with_headless $TEST_BOOL $TEST_ARGUMENT

}

function run_swing_component_test_set {
  TEST_ARGUMENT=$1
  TEST_BOOL=$2

  echo "---------------------------------------------------------------------"
  echo "use -Djava.awt.headless=$TEST_BOOL and set display to $XDISPLAY"
  echo "---------------------------------------------------------------------"
  export DISPLAY=$XDISPLAY
  run_java_with_headless $TEST_BOOL $TEST_ARGUMENT

}

function run_swing_component_test_fake {
  TEST_ARGUMENT=$1
  TEST_BOOL=$2
  
  echo "---------------------------------------------------------------------"
  echo "use -Djava.awt.headless=$TEST_BOOL and set display to invalid :666"
  echo "---------------------------------------------------------------------"
  export DISPLAY=':666'
  run_java_with_headless $TEST_BOOL $TEST_ARGUMENT
}

function processResults {

  if [ $1 -eq 0 ]; then
    let "PASSED+=1"
    TEST=$(printXmlTest "tps" "$2" "0")
    BODY+="$TEST
    " # new line to improve clarity, also is used in TPS/tesultsToJtregs.sh
    echo "$2 PASSED\n"
  else
    let "FAILED+=1"
    TEST=$(printXmlTest "tps" "$2" "0" "$LOGFILE" "$LOGFILE")
    BODY+="$TEST
    " # new line to improve clarity, also is used in TPS/tesultsToJtregs.sh
    echo "$2 FAILED\n"
  fi

}
set -e
FAILED=0
PASSED=0
IGNORED=0
BODY=""

if [ "x$RFaT" == "x" ]; then
  readonly RFaT=`mktemp -d`
  git clone https://github.com/rh-openjdk/run-folder-as-tests.git ${RFaT} 1>&2
  ls -l ${RFaT}  1>&2
fi

source ${RFaT}/jtreg-shell-xml.sh

if [[ -z "${WORKSPACE}" ]]; then
  WORKSPACE=~/workspace
  mkdir -p $WORKSPACE
fi

if [ "x$TMPRESULTS" == "x" ]; then
  TMPRESULTS=$WORKSPACE
  mkdir -p $TMPRESULTS
fi

touch $TMPRESULTS/testHeadlessComponent.txt


pushd $WORKSPACE

popd

LOGFILE=$TMPRESULTS/testHeadlessComponent.log

installAlternativeJDK

JAVAC_BINARY="${BOOTJDK_DIR}/bin/javac"
if [ "$OS" == "mac" ]; then
  JAVAC_BINARY="${BOOTJDK_DIR}/Contents/Home/bin/javac"
fi

#use bootjdk javac
#other classes depend on this one, so we might as well just compile the main class
cp -r $SCRIPT_DIR/testHeadlessComponents $WORKSPACE
ls $WORKSPACE
pushd $WORKSPACE/testHeadlessComponents/jreTestingSwingComponents/src

cp=`mktemp -d`
$JAVAC_BINARY `find . -type f -name "*.java"` -d $cp

declare -A resArray
set +e

if [[ -z "${OTOOL_ARCH}" ]] ; then
    RUN_ARCH=$(uname -m)
else
    RUN_ARCH=$OTOOL_ARCH
fi

for testOption in compatible incompatible; do
  for headless in true false; do
    if [[ "$JRESDK" == "jre" || "$JRESDK" == "jdk" && (("${testOption}${headless}" == "compatibletrue") || ("${testOption}${headless}" == "incompatiblefalse")) ]] ; then
      run_swing_component_test_unset ${testOption} ${headless} >> $LOGFILE 2>&1
      resArray["jre_headless_${testOption}_${headless}_display_unset"]=$?
    fi
  
    if [[ "x$XDISPLAY" == *x* ]] ; then
      echo "skipping tests with display set, as the default display was not defined"
    else
      run_swing_component_test_set ${testOption} ${headless} >> $LOGFILE 2>&1
      resArray["jre_headless_${testOption}_${headless}_display_set"]=$?
    fi
    if [[ "$JRESDK" == "jre" || "$JRESDK" == "jdk" && (("${testOption}${headless}" == "compatibletrue") || ("${testOption}${headless}" == "incompatiblefalse")) ]] ; then
      run_swing_component_test_fake ${testOption} ${headless} >> $LOGFILE 2>&1
      resArray["jre_headless_${testOption}_${headless}_display_fake"]=$?
    fi
  done
done

popd
set -e
set -x

for key in ${!resArray[@]}; do
  processResults ${resArray[$key]} $key
done

let "TESTS = $FAILED + $PASSED + $IGNORED"

XMLREPORT=$TMPRESULTS/testHeadlessComponent.jtr.xml
printXmlHeader $PASSED $FAILED $TESTS $IGNORED "testHeadlessComponent" > $XMLREPORT
echo "$BODY" >> $XMLREPORT
printXmlFooter >> $XMLREPORT

echo $JAVA_HOME

for val in ${resArray[@]}; do
  if [[ "$val" -ne "0" ]]; then
    exit 1
  fi
done

exit 0
