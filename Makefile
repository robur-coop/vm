PREFIX=/usr/local

all:

PROG_MAIN=src/vm.sh
PROG_LIB=src/functions.sh
PROG_SUB=src/vm-clone.sh \
	 src/vm-console.sh \
	 src/vm-create.sh \
	 src/vm-list.sh \
	 src/vm-wait.sh \
	 src/vm-ps.sh \
	 src/vm-remove.sh \
	 src/vm-rename.sh \
	 src/vm-start.sh \
	 src/vm-stop.sh \
	 src/vm-top.sh

install:
	install -m 0755 $(PROG_MAIN) $(PREFIX)/sbin/vm
	mkdir -p $(PREFIX)/share/vm
	install -m 0644 $(PROG_LIB) $(PREFIX)/share/vm
	install -m 0755 $(PROG_SUB) $(PREFIX)/share/vm

check:
	shellcheck -ax ${PROG_MAIN} ${PROG_SUB}

.PHONY: all install check
