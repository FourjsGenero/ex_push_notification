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

# These are not required: Defined implicitely by gmabuildtool...
# APP_PERMISSIONS= com.google.android.c2dm.permission.RECEIVE, com.example.pushclient.permission.C2D_MESSAGE
#    --build-app-permissions "$APP_PERMISSIONS" 

builddir=/tmp/build_pushdemo
appdir=$builddir/appdir
outdir=$builddir/gma

mkdir -p $outdir

gmabuildtool build \
    --android-sdk $ANDROID_HOME \
    --clean \
    --build-force-scaffold-update --build-quietly \
    --build-output-apk-name pushdemo \
    --build-apk-outputs $outdir \
    --build-app-genero-program $appdir \
    --build-app-name "Push Demo" \
    --build-app-package-name com.fourjs.pushdemo \
    --build-app-version-code 1000 \
    --build-app-version-name "1.0" \
    --build-mode release \
    --build-app-icon-mdpi   resources/android/icons/icon_48x48.png \
    --build-app-icon-hdpi   resources/android/icons/icon_72x72.png \
    --build-app-icon-xhdpi  resources/android/icons/icon_96x96.png \
    --build-app-icon-xxhdpi resources/android/icons/icon_144x144.png

gmabuildtool test --test-apk $outdir/pushdemo.apk
