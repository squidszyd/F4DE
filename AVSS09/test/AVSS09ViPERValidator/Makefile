# AVSS09/test/AVSS09ViPERValidator
include ../../../Makefile_common

AVSS09ViPERValidator_tester=AVSS09ViPERValidator_tester.pl

CLEAR07_XSD=../../../CLEAR07/data

ifdef F4DE_TEST_INSTALLDIR
AVSS09ViPERValidator=../../../bin/AVSS09ViPERValidator
else
AVSS09ViPERValidator_exec=AVSS09ViPERValidator.pl
AVSS09ViPERValidator_reldir=../../tools/AVSS09ViPERValidator
AVSS09ViPERValidator=${AVSS09ViPERValidator_reldir}/${AVSS09ViPERValidator_exec}
endif
AVSS09ViPERValidator_Add=--CLEARxsd ${CLEAR07_XSD}

CLEAR07_lib=../../../CLEAR07/lib
AVSS09_lib=../lib
F4DE_lib=../../../common/lib
PERL=${F4DEPERL} -I${CLEAR07_lib} -I${AVSS09_lib} -I${F4DE_lib}

all:
	@echo "Nothing to do"

install:
	@echo "Nothing to do for install"

check: ${AVSS09ViPERValidator_tester_exec} ${AVSS09ViPERValidator}
	@(${PERL} ${AVSS09ViPERValidator_tester} ${AVSS09ViPERValidator} $@ ${AVSS09ViPERValidator_Add})

makecheckfiles: ${AVSS09ViPERValidator_tester_exec} ${AVSS09ViPERValidator}
	@(${PERL} ${AVSS09ViPERValidator_tester} ${AVSS09ViPERValidator} $@ ${AVSS09ViPERValidator_Add})

makecompcheckfiles: ${AVSS09ViPERValidator_tester_exec} ${AVSS09ViPERValidator}
	@(${PERL} ${AVSS09ViPERValidator_tester} ${AVSS09ViPERValidator} $@ ${AVSS09ViPERValidator_Add})

cleanresfiles:
	@rm -f res_*.txt
