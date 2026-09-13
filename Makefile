PREFIX ?= $(HOME)/.local
LIBDIR := $(PREFIX)/lib/agent-widgets

.PHONY: build test lint install uninstall

build:
	swift build -c release --product aw

test:
	swift test
	cd Kit && swift test

lint:
	swiftlint --strict

install: build
	mkdir -p "$(LIBDIR)/bin" "$(PREFIX)/bin"
	ditto .build/release/aw "$(LIBDIR)/bin/aw"
	ditto Templates "$(LIBDIR)/Templates"
	if [ -d skills ]; then ditto skills "$(LIBDIR)/skills"; fi
	rsync -a --delete --exclude .build --exclude .swiftpm Kit/ "$(LIBDIR)/Kit/"
	ln -sf "$(LIBDIR)/bin/aw" "$(PREFIX)/bin/aw"

uninstall:
	mkdir -p "$(HOME)/.Trash/agent-widgets"
	mv "$(LIBDIR)" "$(HOME)/.Trash/agent-widgets/lib-$$(date +%s)"
	rm -f "$(PREFIX)/bin/aw"
