diff --git a/epochX/cudacpp/gg_tt.mad/SubProcesses/makefile b/epochX/cudacpp/gg_tt.mad/SubProcesses/makefile
index cce95279..95f79f3c 100644
--- a/epochX/cudacpp/gg_tt.mad/SubProcesses/makefile
+++ b/epochX/cudacpp/gg_tt.mad/SubProcesses/makefile
@@ -1,6 +1,17 @@
 include ../../Source/make_opts
 FFLAGS+= -w
 
+# Enable the C preprocessor https://gcc.gnu.org/onlinedocs/gfortran/Preprocessing-Options.html
+FFLAGS+= -cpp 
+
+# Enable ccache if USECCACHE=1
+ifeq ($(USECCACHE)$(shell echo $(CXX) | grep ccache),1)
+  override CXX:=ccache $(CXX)
+endif
+ifeq ($(USECCACHE)$(shell echo $(FC) | grep ccache),1)
+  override FC:=ccache $(FC)
+endif
+
 # Load additional dependencies of the bias module, if present
 ifeq (,$(wildcard ../bias_dependencies))
 BIASDEPENDENCIES =
@@ -24,7 +35,7 @@ else
     MADLOOP_LIB =
 endif
 
-LINKLIBS = $(LINK_MADLOOP_LIB) $(LINK_LOOP_LIBS) -L../../lib/ -ldhelas -ldsample -lmodel -lgeneric -lpdf -lcernlib $(llhapdf) -lbias 
+LINKLIBS = $(LINK_MADLOOP_LIB) $(LINK_LOOP_LIBS) -L$(LIBDIR) -ldhelas -ldsample -lmodel -lgeneric -lpdf -lcernlib $(llhapdf) -lbias 
 
 LIBS = $(LIBDIR)libbias.$(libext) $(LIBDIR)libdhelas.$(libext) $(LIBDIR)libdsample.$(libext) $(LIBDIR)libgeneric.$(libext) $(LIBDIR)libpdf.$(libext) $(LIBDIR)libmodel.$(libext) $(LIBDIR)libcernlib.$(libext) $(MADLOOP_LIB) $(LOOP_LIBS)
 
@@ -37,23 +48,65 @@ ifeq ($(strip $(MATRIX_HEL)),)
 endif
 
 
-PROCESS= driver.o myamp.o genps.o unwgt.o setcuts.o get_color.o \
+PROCESS= myamp.o genps.o unwgt.o setcuts.o get_color.o \
          cuts.o cluster.o reweight.o initcluster.o addmothers.o setscales.o \
-	 idenparts.o dummy_fct.o \
-         $(patsubst %.f,%.o,$(wildcard auto_dsig*.f)) \
+	 idenparts.o dummy_fct.o
+
+DSIG=driver.o $(patsubst %.f,%.o,$(wildcard auto_dsig*.f))
+DSIG_cudacpp=driver_cudacpp.o $(patsubst %.f,%_cudacpp.o,$(wildcard auto_dsig*.f))
 
 SYMMETRY = symmetry.o idenparts.o 
 
 # Binaries
 
-$(PROG): $(PROCESS) auto_dsig.o $(LIBS) $(MATRIX)
-	$(FC) -o $(PROG) $(PROCESS) $(MATRIX) $(LINKLIBS) $(LDFLAGS) $(BIASDEPENDENCIES) -fopenmp
+ifeq (,$(wildcard fbridge.inc))
+all: libs $(PROG)
+else
+all: libs $(PROG) c$(PROG)_cudacpp g$(PROG)_cudacpp
+endif
+
+$(PROG): $(PROCESS) $(DSIG) auto_dsig.o $(LIBS) $(MATRIX) counters.o
+	$(FC) -o $(PROG) $(PROCESS) $(DSIG) $(MATRIX) $(LINKLIBS) $(LDFLAGS) $(BIASDEPENDENCIES) -fopenmp counters.o
+
+libs:
+	cd ../../Source; make
+ifneq (,$(wildcard fbridge.inc))
+	$(MAKE) -f $(PLUGIN_MAKEFILE)
+endif
+
+processid_short=$(shell basename $(CURDIR) | awk -F_ '{print $$(NF-1)"_"$$NF}')
+PLUGIN_COMMONLIB = mg5amc_common
+PLUGIN_COMMONLIB = mg5amc_common
+PLUGIN_CXXLIB = mg5amc_$(processid_short)_cpp
+PLUGIN_CULIB = mg5amc_$(processid_short)_cuda
+PLUGIN_MAKEFILE = Makefile
+
+# On Linux, set rpath to LIBDIR to make it unnecessary to use LD_LIBRARY_PATH
+# Use relative paths with respect to the executables ($ORIGIN on Linux)
+# On Darwin, building libraries with absolute paths in LIBDIR makes this unnecessary
+ifeq ($(UNAME_S),Darwin)
+  override LIBFLAGSRPATH =
+else
+  override LIBFLAGSRPATH = -Wl,-rpath,'$$ORIGIN/$(LIBDIR)'
+endif
+
+c$(PROG)_cudacpp: $(PROCESS) $(DSIG_cudacpp) auto_dsig.o $(LIBS) $(MATRIX) counters.o $(LIBDIR)/lib$(PLUGIN_CXXLIB).so
+	$(FC) -o c$(PROG)_cudacpp $(PROCESS) $(DSIG_cudacpp) $(MATRIX) $(LINKLIBS) $(LDFLAGS) $(BIASDEPENDENCIES) -fopenmp counters.o -L$(LIBDIR) -l$(PLUGIN_COMMONLIB) -l$(PLUGIN_CXXLIB) $(LIBFLAGSRPATH)
+
+g$(PROG)_cudacpp: $(PROCESS) $(DSIG_cudacpp) auto_dsig.o $(LIBS) $(MATRIX) counters.o $(LIBDIR)/lib$(PLUGIN_CULIB).so
+	$(FC) -o g$(PROG)_cudacpp $(PROCESS) $(DSIG_cudacpp) $(MATRIX) $(LINKLIBS) $(LDFLAGS) $(BIASDEPENDENCIES) -fopenmp counters.o -L$(LIBDIR) -l$(PLUGIN_COMMONLIB) -l$(PLUGIN_CULIB) $(LIBFLAGSRPATH)
+
+$(LIBDIR)/lib$(PLUGIN_CXXLIB).so $(LIBDIR)/lib$(PLUGIN_CULIB).so:
+	$(MAKE) -f $(PLUGIN_MAKEFILE)
+
+counters.o: counters.cpp timer.h
+	$(CXX) -std=c++11 -Wall -Wshadow -Wextra -c $< -o $@
 
 $(PROG)_forhel: $(PROCESS) auto_dsig.o $(LIBS) $(MATRIX_HEL)
 	$(FC) -o $(PROG)_forhel $(PROCESS) $(MATRIX_HEL) $(LINKLIBS) $(LDFLAGS) $(BIASDEPENDENCIES) -fopenmp
 
 gensym: $(SYMMETRY) configs.inc $(LIBDIR)libmodel.$(libext) $(LIBDIR)libgeneric.$(libext)
-	$(FC) -o gensym $(SYMMETRY) -L../../lib/ -lmodel -lgeneric -lpdf $(llhapdf) $(LDFLAGS)
+	$(FC) -o gensym $(SYMMETRY) -L$(LIBDIR) -lmodel -lgeneric -lpdf $(llhapdf) $(LDFLAGS)
 
 $(LIBDIR)libmodel.$(libext): ../../Cards/param_card.dat
 	cd ../../Source/MODEL; make
@@ -68,7 +121,9 @@ $(LIBDIR)libpdf.$(libext):
 $(MATRIX): %.o: %.f
 	$(FC) $(FFLAGS) $(MATRIX_FLAG) -c $< -I../../Source/ -fopenmp
 %.o: %.f
-	$(FC) $(FFLAGS) -c $< -I../../Source/ -fopenmp
+	$(FC) $(FFLAGS) -c $< -I../../Source/ -fopenmp -o $@
+%_cudacpp.o: %.f
+	$(FC) $(FFLAGS) -c -DMG5AMC_MEEXPORTER_CUDACPP $< -I../../Source/ -fopenmp -o $@
 
 # Dependencies
 
@@ -89,4 +144,16 @@ unwgt.o: genps.inc nexternal.inc symswap.inc cluster.inc run.inc message.inc \
 initcluster.o: message.inc
 
 clean:
-	$(RM) *.o gensym madevent madevent_forhel
+ifeq (,$(wildcard fbridge.inc))
+	$(RM) *.o gensym $(PROG) $(PROG)_forhel
+else
+	$(RM) *.o gensym $(PROG) $(PROG)_forhel *$(PROG)_cudacpp
+endif
+
+cleanall:
+	make clean
+	make -C ../../Source clean
+	rm -rf $(LIBDIR)libbias.$(libext)
+ifneq (,$(wildcard fbridge.inc))
+	$(MAKE) -f $(PLUGIN_MAKEFILE) cleanall
+endif