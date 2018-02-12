.PHONY: appdir package_gma package_gmi

FORMS=\
  pushclient.42f

MAIN=\
  main.42m

all:: $(FORMS) $(MAIN)

BUILDDIR=/tmp/build_pushdemo
$(BUILDDIR):
	$(MKDIR) $(BUILDDIR)

APPDIR=$(BUILDDIR)/appdir
$(APPDIR): $(BUILDDIR)
	$(MKDIR) $(APPDIR)

appdir:: all $(APPDIR)
	rm -rf $(APPDIR)/*
	$(CP) $(FORMS) $(APPDIR)
	$(CP) $(MAIN) $(APPDIR)

package_gma:: appdir
	sh build_gma.sh

package_gmi:: appdir
	sh build_gmi.sh

clean::
	rm -rf $(APPDIR)

include ../makefile.incl

