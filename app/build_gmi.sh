if test -z "$GMIDEVICE"
then
    echo "Must set GMIDEVICE env var to define the target device"
    exit 1
fi
if test -z "$GMICERTIFICATE"
then
    echo "Must set GMICERTIFICATE env var to define the app certificate"
    exit 1
fi
if test -z "$GMIPROVISIONING"
then
    echo "Must set GMIPROVISIONING env var to define the provisioning profile"
    exit 1
fi
if test -z "$GMIAPPID"
then
    echo "Must set GMIAPPID env var to define the bundle id of the app"
    exit 1
fi

builddir=/tmp/build_pushdemo
appdir=$builddir/appdir
outdir=$builddir/gmi

mkdir -p $outdir

gmibuildtool \
   --app-name "Push Demo" \
   --app-version "v1.0" \
   --output $outdir/pushdemo.ipa \
   --program-files $appdir \
   --icons resources/ios/icons \
   --storyboard resources/ios/LaunchScreen.storyboard \
   --bundle-id "$GMIAPPID" \
   --device "$GMIDEVICE" \
   --certificate "$GMICERTIFICATE" \
   --provisioning "$GMIPROVISIONING"

