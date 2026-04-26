# Simple POSIX-compatible Makefile
# Works with both gmake and bmake

SH = /bin/sh

.PHONY: all build check clean package test

all: build
test: check
dist: package

build: check
	@echo "Running build script..."
	$(SH) ./build.sh

check:
	@echo "Running compliance check script..."
	$(SH) ./check.sh

clean:
	@echo "Running clean script..."
	$(SH) ./clean.sh

package:
	@echo "Running packaging script..."
	$(SH) ./package.sh