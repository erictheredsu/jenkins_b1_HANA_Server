#!/bin/bash
#just call buildRPM

#environment variables required
#RPM_OUTPUT_PATH
#P4_ROOT_PATH #p4 root path, in front of BUSMB_B1
#BRANCH
#OUTPUT_DIR

#local environment variables
SBO_SOURCE_PATH="$P4_ROOT_PATH/BUSMB_B1/SBO/$BRANCH"
XAPP_TGZ_PATH="$SBO_SOURCE_PATH/Components/XApp/Framework/bin/SBO_XAPP.tgz"
B1A_PACKAGE_PATH="$OUTPUT_DIR/bin"
# echo "B1A_PACKAGE_PATH -> ${B1A_PACKAGE_PATH}"
#RPM_SPEC_PATH="./spec"
#VERSION=$(cat $PACKAGES_ROOT/version.txt)
BUILD_ROOT=/tmp/B1Installer
PREFIX=/opt/sap/SAPBusinessOne
BUILD_ROOT_B1A=$BUILD_ROOT$PREFIX/AnalyticsPlatform
BUILD_ROOT_XAPP=$BUILD_ROOT$PREFIX/Common/support/xapps
PATH_SPEC_B1A="$SBO_SOURCE_PATH/BuildBuilder/RPM/Projects/SBOServerTools/Packages/AnalyticsPlatform"
PATH_SPEC_XAPP="$SBO_SOURCE_PATH/BuildBuilder/RPM/Projects/SBOServerTools/Packages/ServerTools"
SPEC_XAPP="$PATH_SPEC_XAPP/B1ACommon.spec"
SPEC_B1A="$PATH_SPEC_B1A/XApp.spec"
SPEC_LIST="$SPEC_XAPP $SPEC_B1A"

function prepare() {
	RESULT=0
	#clean-up work folder
	echo "clean-up work folder..."
	rm -rf $BUILD_ROOT

	#generate version
	echo "generate version..."
	if [ ! -f ${SBO_SOURCE_PATH}/Source/Infrastructure/Common/__SBO_Version.h ]; then
	    echo "Please sync ${SBO_SOURCE_PATH}/Source/Infrastructure/Common/__SBO_Version.h into your perforce spec!"
	    exit 1
	fi

	grep "#define SBO_VERSION_STR" ${SBO_SOURCE_PATH}/Source/Infrastructure/Common/__SBO_Version.h > /tmp/v.txt
	b1_version=$(sed -r 's/^#define SBO_VERSION_STR\s+"([0-9]+\.[0-9]+)\.([0-9]+).*/\1\2/' /tmp/v.txt)
	grep "#define SBO_SPECIAL_BUILD_STR" ${SBO_SOURCE_PATH}/Source/Infrastructure/Common/__SBO_Version.h > /tmp/v.txt
	patch_level=$(sed -r 's/^#define SBO_SPECIAL_BUILD_STR\s+"([0-9]+).*/\1/' /tmp/v.txt)

	VERSION=${b1_version}${patch_level}
	echo "version: "$VERSION
}

#function for create single rpm
function create_rpm() {
	#PACKAGE=$1
	FILENAME=$1
	RPM_SPEC_PATH=$2
	#TYPE=$3

	echo "RPM creation"
	cp "$RPM_SPEC_PATH/$FILENAME" "$RPM_SPEC_PATH/$FILENAME"_versioned
	chmod a+w "$RPM_SPEC_PATH/$FILENAME"_versioned
	sed -i "s/Version: "\{"Version"\}"/Version: $VERSION/g" "$RPM_SPEC_PATH/$FILENAME"_versioned
	rpmbuild -bb "$RPM_SPEC_PATH/$FILENAME"_versioned
	if [ $? -ne 0 ] && [ "${ERROR_STOP}" == "true" ] ; then
		rm "$RPM_SPEC_PATH/$FILENAME"_versioned
		echo "error: rpm build $RPM_SPEC_PATH/$FILENAME fails."
		exit 1
	fi
	#rm "$RPM_SPEC_PATH/$FILENAME"_versioned
	cp $BUILD_ROOT/x86_64/*.rpm "$RPM_OUTPUT_PATH"
}

#function for build rpm
function buildRPM() {
	echo "start build RPM..."
	# export -p | grep OUTPUT_DIR
	prepare

	for FILE in $SPEC_LIST ; do

		FILENAME=$(basename "$FILE")
		PACKAGE="${FILENAME%.*}"
		
		echo "Creating ... " $PACKAGE
		echo "Build rpm with spec: " $FILENAME

		if [ -d $BUILD_ROOT ]; then
			rm -rf $BUILD_ROOT
		fi
		
		mkdir -p $BUILD_ROOT$PREFIX

		case $PACKAGE in
		"XApp")
			SPEC_PATH=$PATH_SPEC_XAPP
			mkdir -p $BUILD_ROOT_XAPP
			cp $XAPP_TGZ_PATH $BUILD_ROOT_XAPP
			;;
		"B1ACommon")
			# export -p | grep OUTPUT_DIR
			SPEC_PATH=$PATH_SPEC_B1A
			mkdir -p $BUILD_ROOT_B1A/webapps
			# echo "B1A_PACKAGE_PATH -> ${B1A_PACKAGE_PATH}"
			cp $B1A_PACKAGE_PATH/Replication-1.0.jar $BUILD_ROOT_B1A
			cp $B1A_PACKAGE_PATH/Common-1.0.jar $BUILD_ROOT_B1A
			cp $B1A_PACKAGE_PATH/initialization.jar $BUILD_ROOT_B1A
			cp $B1A_PACKAGE_PATH/Enablement.war $BUILD_ROOT_B1A/webapps/B1A_Enablement.war
			cp $B1A_PACKAGE_PATH/IMCC.war $BUILD_ROOT_B1A/webapps/B1A_IMCC.war
			cp $B1A_PACKAGE_PATH/sap.war $BUILD_ROOT_B1A/webapps/B1A_sap.war
			cp $B1A_PACKAGE_PATH/conf.zip $BUILD_ROOT_B1A
			;;
		*)
			echo "copy nothing"
			;;
		esac
		
		create_rpm $FILENAME $SPEC_PATH
		TEMP=$?
		if [ $TEMP -ne 0 ]; then
			RESULT=$TEMP
		fi
	done

	# clean work folder
	rm -rf $BUILD_ROOT

	return $RESULT
}

echo "build_rpm.sh successfully imported."
