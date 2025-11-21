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

function processResults {

  if [ $1 -eq 0 ]; then
    let "PASSED+=1"
    TEST=$(printXmlTest "thc" "$2" "0")
    BODY+="$TEST"
    echo "$2 PASSED\n"
  else
    let "FAILED+=1"
    TEST=$(printXmlTest "thc" "$2" "0" "$LOGFILE" "$LOGFILE")
    BODY+="$TEST"
    echo "$2 FAILED\n"
  fi

}
set -e
FAILED=0
PASSED=0
IGNORED=0
BODY=""

source $SCRIPT_DIR/RFaT/jtreg-shell-xml.sh

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

#TEST_JDK_HOME always contains link to the home directory of the available SDK

JAVAC_BINARY="${TEST_JDK_HOME}/bin/javac"

#JAVA_TO_TEST can contain either link to SDK or JRE java executable, however always the java that we want to test with
JAVA=$JAVA_TO_TEST
pushd $SCRIPT_DIR
  $JAVAC_BINARY `find . -type f -name "*.java"`
  cp="$SCRIPT_DIR/testHeadlessComponents/jreTestingSwingComponents/src"
popd

declare -A resArray
set +e

if [[ -z "${ARCH}" ]] ; then
    RUN_ARCH=$(uname -m)
fi

for testOption in compatible incompatible; do
  for headless in true false; do
    if [[ "$JREJDK" == "jre" || "$JREJDK" == "jdk" && (("${testOption}${headless}" == "compatibletrue") || ("${testOption}${headless}" == "incompatiblefalse")) ]] ; then
      run_swing_component_test_unset ${testOption} ${headless} >> $LOGFILE 2>&1
      resArray["jre_headless_${testOption}_${headless}_display_unset"]=$?
    fi
  
    if [[ "x$XDISPLAY" == "x" ]] ; then
      echo "skipping tests with display set, as the default display was not defined"
    else
      run_swing_component_test_set ${testOption} ${headless} >> $LOGFILE 2>&1
      resArray["jre_headless_${testOption}_${headless}_display_set"]=$?
    fi
    if [[ "$JREJDK" == "jre" || "$JREJDK" == "jdk" && (("${testOption}${headless}" == "compatibletrue") || ("${testOption}${headless}" == "incompatiblefalse")) ]] ; then
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
ls -la $XMLREPORT

ls 

for val in ${resArray[@]}; do
  if [[ "$val" -ne "0" ]]; then
    exit 1
  fi
done

exit 0
