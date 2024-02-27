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
    JAVA=$JAVA_HOME/bin/java
elif [ "$platform" == "Darwin" ]; then
    # Mac-specific code
    OS="mac"
    JAVA=$JAVA_HOME/bin/java
    #JAVA=java
elif [ "${platform#"MINGW64_NT"}" != "$platform" ]; then
    # Windows (MinGW) specific code
    OS="windows"
    JAVA=$JAVA_HOME/bin/java
elif [ "${platform#"CYGWIN_NT"}" != "$platform" ]; then
    # Windows (CygWin) specific code
    OS="windows"
    JAVA=$JAVA_HOME/bin/java
else
    echo "Unsupported platform"
    exit 1
fi

function unwrap_file_to_location() {
  if [ "$OS" == "mac" -o "$OS" == "linux" ]; then
    tar --strip-components=1 -xf $1 -C $2
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
  $JAVA -cp $cp -Djava.awt.headless=$1 MainRunner -test=$COMPONENTS_TO_TEST -jreSdkHeadless=$JREJDK -displayValue=$DISPLAY
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
fi

mkdir -p $WORKSPACE

if [ "x$TMPRESULTS" == "x" ]; then
  TMPRESULTS=$WORKSPACE
fi

mkdir -p $TMPRESULTS

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

set +e

if [[ -z "${ARCH}" ]] ; then
    RUN_ARCH=$(uname -m)
fi

function processTestResultIntoBodyLine {
  TEST_NAME=$1
  TEST_RESULT=$2
  CURRENT_LOG=$3
  if [ $TEST_RESULT -eq 0 ]; then
    let "PASSED+=1"
    echo $(printXmlTest "thc" "$TEST_NAME" "0") >> $BODY_FILE
    echo "$TEST_NAME PASSED\n"
  else
    let "FAILED+=1"
    echo $(printXmlTest "thc" "$TEST_NAME" "0" "$CURRENT_LOG" "$CURRENT_LOG") >> $BODY_FILE
    echo "$TEST_NAME FAILED\n"
  fi
}

BODY_FILE=$(mktemp)
#the CURRENT_LOG gets rewritten with every execution but is copied into the LOGFILE every time in its entirety
CURRENT_LOG=$(mktemp)
for testOption in compatible incompatible; do
  for headless in true false; do
    if [[ "$JREJDK" == "jre" || "$JREJDK" == "jdk" && (("${testOption}${headless}" == "compatibletrue") || ("${testOption}${headless}" == "incompatiblefalse")) ]] ; then
      run_swing_component_test_unset ${testOption} ${headless} > $CURRENT_LOG 2>&1
      processTestResultIntoBodyLine "jre_headless_${testOption}_${headless}_display_unset" "$?" "$CURRENT_LOG"
      cat $CURRENT_LOG >> $LOGFILE
    fi
  
    if [[ "x$XDISPLAY" == "x" ]] ; then
      echo "skipping tests with display set, as the default display was not defined"
    else
      run_swing_component_test_set ${testOption} ${headless} > $CURRENT_LOG 2>&1
      processTestResultIntoBodyLine "jre_headless_${testOption}_${headless}_display_set" "$?" "$CURRENT_LOG"
      cat $CURRENT_LOG >> $LOGFILE
    fi
    if [[ "$JREJDK" == "jre" || "$JREJDK" == "jdk" && (("${testOption}${headless}" == "compatibletrue") || ("${testOption}${headless}" == "incompatiblefalse")) ]] ; then
      run_swing_component_test_fake ${testOption} ${headless} > $CURRENT_LOG 2>&1
      processTestResultIntoBodyLine "jre_headless_${testOption}_${headless}_display_fake" "$?" "$CURRENT_LOG"
      cat $CURRENT_LOG >> $LOGFILE
    fi
  done
done

rm $CURRENT_LOG

popd
set -e
set -x

let "TESTS = $FAILED + $PASSED + $IGNORED"

XMLREPORT=$TMPRESULTS/testHeadlessComponent.jtr.xml
printXmlHeader $PASSED $FAILED $TESTS $IGNORED "testHeadlessComponent" > $XMLREPORT

while IFS= read -r LINE; do
    printf "%s\n" "$LINE" >> "$XMLREPORT"
done < $BODY_FILE


#cat "$BODY_FILE" >> $XMLREPORT
printXmlFooter >> $XMLREPORT
ls -la $XMLREPORT

rm $BODY_FILE

ls 

for val in ${resArray[@]}; do
  if [[ "$val" -ne "0" ]]; then
    exit 1
  fi
done

exit 0
