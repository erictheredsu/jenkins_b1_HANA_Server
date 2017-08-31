#!/bin/bash

#environment variables required
#P4_ROOT_PATH #p4 root path, in front of BUSMB_B1
#BRANCH

# export OUTPUT_DIR=$WORKSPACE/b1ah_release
SRC_DIR=$P4_ROOT_PATH/BUSMB_B1/SBO/${BRANCH}/Source/Infrastructure
XAPP_SRC_DIR=$P4_ROOT_PATH/BUSMB_B1/SBO/${BRANCH}/Components/XApp/Framework/tools
B1AH_BUILD_SCRIPT=$SRC_DIR/B1analysis/build/build.xml
XAPP_BUILD_SCRIPT=$XAPP_SRC_DIR/build.xml
XML_RESOURCEWORLD=$P4_ROOT_PATH/BUSMB_B1/SBO/${BRANCH}/Source/Client/XmlResources/ResourceWorld.xml
XML_TOOL_DIR=$P4_ROOT_PATH/BUSMB_B1/SBO/${BRANCH}/Source/ThirdParty/XmlResourceTools/Release/

function buildB1AH() {
    rm -rf $RPM_OUTPUT_PATH
    mkdir -p $RPM_OUTPUT_PATH

    rm -rf $OUTPUT_DIR
    mkdir -p $OUTPUT_DIR

    # build b1ah
    ant -f $B1AH_BUILD_SCRIPT
    if [ $? -ne 0 ]; then
        echo "failed to build b1ah (ant)"
        exit 1
    fi

    chmod -R a+w $P4_ROOT_PATH
    su - wineadm <<EOF
pushd ${XML_TOOL_DIR}  
wine XmlCompiler.exe --mode=WebTexts --config=x86 ${XML_RESOURCEWORLD} 
popd
EOF
    # build xapp
    ant -f $XAPP_BUILD_SCRIPT
    if [ $? -ne 0 ]; then
        echo "failed to build xapp (ant)"
        exit 1
    fi

    # rm -rf $BUILDS_POOL/$BRANCH/rpm
    # cp -rf $RPM_OUTPUT_PATH $BUILDS_POOL/$BRANCH/
}

echo "build.sh successfully imported."