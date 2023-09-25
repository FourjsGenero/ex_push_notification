if test -z "$ANDROID_HOME"
then
    echo "Must set ANDROID_HOME env var"
    exit 1
fi
if test -z "$JAVA_HOME"
then
    echo "Must set JAVA_HOME env var"
    exit 1
fi

# Permission android.permission.POST_NOTIFICATIONS is set by default with GMA 4.01.06

appdir=/tmp/appdir_pushdemo

rootdir=/tmp/build_pushdemo
rm -rf $rootdir
mkdir -p $rootdir

outdir=/tmp

if test -n "$FGLGBCDIR"
then
    bgr_option="-bgr $FGLGBCDIR"
fi

gmabuildtool build ${bgr_option} \
    --android-sdk $ANDROID_HOME \
    --clean \
    --build-apk-outputs $outdir \
    --build-output-apk-name pushdemo \
    --root-path $rootdir \
    --main-app-path $appdir/main.42m \
    --build-app-name "Push Demo" \
    --build-app-package-name com.fourjs.pushdemo \
    --build-app-version-code 1010 \
    --build-app-version-name "1.1" \
    --build-mode release \
    --build-app-icon-mdpi   resources/android/icons/icon_48x48.png \
    --build-app-icon-hdpi   resources/android/icons/icon_72x72.png \
    --build-app-icon-xhdpi  resources/android/icons/icon_96x96.png \
    --build-app-icon-xxhdpi resources/android/icons/icon_144x144.png

gmabuildtool test --test-apk $outdir/pushdemo.apk
