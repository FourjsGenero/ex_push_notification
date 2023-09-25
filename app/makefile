.PHONY: appdir package_gma package_gmi

FORMS=\
  pushclient.42f

MAIN=\
  main.42m

FCM_CONFIG_FILE=resources/android/google-services.json

all:: $(FORMS) $(MAIN)

APPDIR=/tmp/appdir_pushdemo
$(APPDIR):
	$(MKDIR) $(APPDIR)

appdir:: all $(APPDIR)
	rm -rf $(APPDIR)/*
	$(CP) $(FORMS) $(APPDIR)
	$(CP) $(MAIN) $(APPDIR)

appdir-gma:: $(FCM_CONFIG_FILE)
	$(CP) $(FCM_CONFIG_FILE) $(APPDIR)

package_gma:: appdir appdir-gma
	sh build_gma.sh

package_gmi:: appdir
	sh build_gmi.sh

clean::
	rm -rf $(APPDIR)

include ../makefile.incl

