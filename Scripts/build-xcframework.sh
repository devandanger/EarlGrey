xcodebuild archive -scheme EarlGrey -archivePath ./build/iphonesimulator.xcarchive -sdk iphonesimulator SKIP_INSTALL=NO
xcodebuild archive -scheme EarlGrey -archivePath ./build/iphoneos.xcarchive -sdk iphoneos SKIP_INSTALL=NO
xcodebuild -create-xcframework -framework ./build/iphoneos.xcarchive/Products/Library/Frameworks/EarlGrey.framework -framework ./build/iphonesimulator.xcarchive/Products/Library/Frameworks/EarlGrey.framework -output ./build/EarlGrey.xcframework
