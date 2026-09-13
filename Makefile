prefix        ?= $(or $(PREFIX),/usr/local)
sbindir       ?= $(prefix)/sbin
sysconfdir    ?= /etc
openrcinitdir ?= $(sysconfdir)/init.d
systemdsystemunitdir ?= $(sysconfdir)/systemd/system

INIT_SYSTEM   ?= $(if $(wildcard /run/openrc),openrc,\
                 $(if $(wildcard /run/systemd/system),systemd,))

SVC_NAME      := prox-init

ifeq ($(INIT_SYSTEM), openrc)
SVC_FILE_SRC  := dist/openrc/prox-init
SVC_FILE_DEST := $(DESTDIR)$(openrcinitdir)/$(SVC_NAME)
endif
ifeq ($(INIT_SYSTEM), systemd)
SVC_FILE_SRC  := dist/systemd/prox-init.service
SVC_FILE_DEST := $(DESTDIR)$(systemdsystemunitdir)/$(SVC_NAME).service
endif

INSTALL       := install
GIT           := git
SED           := sed

MAKEFILE_PATH  = $(lastword $(MAKEFILE_LIST))


#: Print list of targets.
help:
	@printf '%s\n\n' 'List of targets:'
	@$(SED) -En '/^#:.*/{ N; s/^#: (.*)\n([A-Za-z0-9_-]+).*/\2 \1/p }' $(MAKEFILE_PATH) \
		| while read label desc; do printf '%-20s %s\n' "$$label" "$$desc"; done

#: Install prox-init and OpenRC or systemd file (based on INIT_SYSTEM variable).
install: install-common $(if $(SVC_FILE_SRC),install-service)

install-common:
	$(INSTALL) -m 755 -D prox-init "$(DESTDIR)$(sbindir)/prox-init"

install-service:
	$(INSTALL) -m 755 -D $(SVC_FILE_SRC) "$(SVC_FILE_DEST)"
	$(SED) -E -i "s|/usr/local/sbin/|$(sbindir)/|" "$(SVC_FILE_DEST)"

#: Uninstall prox-init and OpenRC or systemd file (based on INIT_SYSTEM variable).
uninstall:
	rm -f "$(DESTDIR)$(sbindir)/prox-init"
	$(if $(SVC_FILE_DEST),rm -f "$(SVC_FILE_DEST)")

#: Update version in the script and README.adoc to $VERSION.
bump-version:
	test -n "$(VERSION)"  # $$VERSION
	$(SED) -E -i "s/^(readonly VERSION)=.*/\1='$(VERSION)'/" prox-init
	$(SED) -E -i "s/^(:version:).*/\1 $(VERSION)/" README.adoc

#: Bump version to $VERSION, create release commit and tag.
release: .check-git-clean | bump-version
	test -n "$(VERSION)"  # $$VERSION
	$(GIT) add .
	$(GIT) commit -m "Release version $(VERSION)"
	$(GIT) tag -s v$(VERSION) -m v$(VERSION)


.check-git-clean:
	@test -z "$(shell $(GIT) status --porcelain)" \
		|| { echo 'You have uncommitted changes!' >&2; exit 1; }

.PHONY: help install install-common install-service uninstall bump-version release .check-git-clean
