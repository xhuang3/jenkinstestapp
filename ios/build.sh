#!/bin/sh
############################################
# File: build.sh
# -----------------------
# Author: edOfTheMountain@acme.com
#
# Command line build:
#   1) clean
#   2) build
#   3) archive
#   4) export IPA
#
# http://shashikantjagtap.net/xcodebuild-deploy-ios-app-command-line/
# https://help.apple.com/itc/apploader/e3#/apdATD1E53-D1E1A1303-D1E53A1126
#

 isInPath=$(which xcodebuild)
 if [ ! -x "${isInPath}" ] ; then
    echo "*** Error xcodebuild not found in path"
    exit 1
 fi

isInPath=$(which xcrun)
 if [ ! -x "${isInPath}" ] ; then
    echo "*** Error xcrun not found in path"
    exit 1
 fi


echo "### Start: Cleaning ###############################################################"
rm -rf build
xcodebuild -project MyApp.xcodeproj -scheme MyApp -destination generic/platform=iOS clean     
echo "### Done: Cleaning ###############################################################"

# Analyze
# xcodebuild -project MyApp.xcodeproj -scheme MyApp -sdk iphoneos clean analyze

echo "### Start: Building ###############################################################"
# xcodebuild -project MyApp.xcodeproj -target MyApp -showBuildSettings
# xcodebuild -project MyApp.xcodeproj -scheme MyApp -destination generic/platform=iOS build    

# Run pod install once before building workspace
pod install 

# Now using a Podfile so have to build workspace not build project
xcodebuild -workspace MyApp.xcworkspace -scheme MyApp -destination generic/platform=iOS build     
echo "### Done: Building ###############################################################"


CFBundleShortVersionString=`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" ./MyApp/Info.plist`
CFBundleVersion=`/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" ./MyApp/Info.plist`
echo "CFBundleShortVersionString: ${CFBundleShortVersionString}"
echo "CFBundleVersion: ${CFBundleVersion}"

ipaFileName=MyApp.ipa
renameIpaFileName="field-scout-${CFBundleShortVersionString}.${CFBundleVersion}.ipa"

echo "### Start: Archiving ###############################################################"
# xcodebuild -project MyApp.xcodeproj -scheme MyApp -sdk iphoneos -configuration AppStoreDistribution archive -archivePath $PWD/build/MyApp.xcarchive

# Now using a Podfile so have to build workspace not build project
xcodebuild -workspace MyApp.xcworkspace -scheme MyApp -sdk iphoneos -configuration AppStoreDistribution archive -archivePath $PWD/build/MyApp.xcarchive
echo "### Done: Archiving ###############################################################"

echo "### Start: Exporting ###############################################################"
xcodebuild -exportArchive -archivePath $PWD/build/MyApp.xcarchive -exportOptionsPlist MyApp/ExportOptions.plist -exportPath $PWD/build
ls -al build
echo "### Done: Exporting ###############################################################"

appArchiveFile=build/${ipaFileName}
if [ ! -f "${appArchiveFile}" ]; then
    echo "*** Error file not found: ${appArchiveFile}"
    exit 1    
fi

# Extract and verify archive contents
echo "### Unzip: ${ipaFileName}  ###############################################################"
( cd build; unzip -q ${ipaFileName} )
( cd build/Payload; xcrun codesign -dv MyApp.app/ )

outputFile=build/Payload/MyApp.app
if [ ! -d "${outputFile}" ]; then
    echo "*** Error file not found: ${outputFile}"
    exit 1    
fi
rm -rf ./build/Payload
rm -rf ./build/Symbols


# altool is used to verify iOS IPA files
altool_path=/Applications/Xcode.app/Contents/Applications/Application\ Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Versions/Current/Support

isInPath=$(which altool)
 if [ ! -x "${isInPath}" ] ; then
    echo "*** Error altool not found in path"
    echo "Expected altool path:\n ${altool_path}"
    exit 1
 fi

# altool validate will trigger a user dialog first time it is run.
# On a jenkins slave you will need to execute manually in a console once, to allow keychain access.
# $ altool --validate-app -f file -u username [-p password] [--output-format xml]
# $ altool --upload-app -f file -u username [-p password] [--output-format xml]
altool --validate-app -f build/${ipaFileName} -u edOfTheMountain@acme.com -p @keychain:"Application Loader: edOfTheMountain@acme.com"
altool --validate-app -f build/${ipaFileName} -u edOfTheMountain@acme.com -p @keychain:"Application Loader: edOfTheMountain@acme.com" --output-format xml > build/validate.xml
altoolValidate=$?
if [ ${altoolValidate} -ne 0 ]; then
    echo "*** Error IPA failed to validate: build/${ipaFileName}"
    echo "See: build/validate.xml"
    exit 1    
fi

echo "Rename build/${ipaFileName} to build/${renameIpaFileName}" 
mv ./build/${ipaFileName} ./build/${renameIpaFileName} 

echo ##############################
echo        Done 
echo ##############################
echo Ready to upload archive to iTunes:
echo "  ${appArchiveFile}"
echo
uploadExample="$( echo altool --upload-app -f build/${renameIpaFileName} -u edOfTheMountain@acme.com -p @keychain:"Application Loader: edOfTheMountain@acme.com" )"
echo "Upload Example:\n ${uploadExample}"
echo
