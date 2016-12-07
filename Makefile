.PHONY: build 

LAST_VER := $(shell git describe --abbrev=0 --tags 2>/dev/null || echo untagged)
IS_DIRTY := $(shell git diff --quiet --ignore-submodules HEAD; echo $$?)
IS_LATEST := $(shell test $(IS_DIRTY) -eq 0 && \
	test `git rev-list -n 1 HEAD 2>/dev/null` -eq `git rev-list -n $(LAST_VER) 2>/dev/null` && \
	echo 1 || echo 0)
VERSION := $(shell test $(IS_LATEST) -eq 1 && \
	echo $(LAST_VER) || echo $(LAST_VER)-next)
GITHASH := $(shell test $(IS_DIRTY) -eq 0 && \
	echo `git rev-parse HEAD` || echo `git rev-parse HEAD`-dirty)

IMPORT_PATH := $(shell go list)
SOURCE_CODE := $(shell go list -f "{{ .Name }}" ./* 2>/dev/null | grep -v main | xargs) $(shell ls | grep vendor)

OS := $(shell go env GOOS)
ARCH := $(shell go env GOARCH)
GO_MAIN := main.go
BINARY := $(shell realpath $(GO_MAIN) | xargs dirname | xargs basename)
BIN := build/$(OS)_$(ARCH)/$(BINARY)
BUILD_CMD := make build

PID := $(shell test -e tmp/$(CMD).pid && cat tmp/$(CMD).pid)

help:
	@ echo "build:	build go files"
	@ echo "	params:"
	@ echo "  	  GO_MAIN: the entry file, default to main.go"
	@ echo "  	  OS: GOOS, default to \`go env GOOS\`"
	@ echo "  	  ARCH: GOARCH, default to \`go env GOARCH\`"
	@ echo "  	  BINARY: the name of the output, defaults to the dirctory name"
	@ echo "	built binary will be \`build/OS_ARCH/BINARY\`"
	@ echo ""
	@ echo "docker:	build docker image"
	@ echo "	image name is set using $$IMAGE"

tag:
ifeq ($(IS_DIRTY), 1)
	@ echo Please commit your changes first
else
	@ git tag $(TAG)
endif

build: 
	@ make build/$(OS)_$(ARCH)

build/%: $(SOURCE_CODE)
	go build -o $(BIN) -ldflags "$(LDFLAGS)" $(GO_MAIN)

build-in-docker: $(SOURCE_CODE)
	docker run --rm \
		-v $(GOPATH)/src:/go/src \
		-w /go/src/$(IMPORT_PATH) \
		golang:1.6 \
		bash -c "$(BUILD_CMD)"

vars:
	@ echo "LAST_VER	$(LAST_VER)"
	@ echo "IS_DIRTY 	$(IS_DIRTY)"
	@ echo "IS_LATEST 	$(IS_LATEST)"
	@ echo "VERSION 	$(VERSION)"
	@ echo "GITHASH 	$(GITHASH)"
	@ echo "IMPORT_PATH 	$(IMPORT_PATH)"
	@ echo "OS 		$(OS)"
	@ echo "ARCH 		$(ARCH)"

fg:
	$(BIN) $(CMD)

bg:
	$(BIN) $(CMD) & echo $$! > tmp/$(CMD).pid;

kill:
	@ kill $(PID) 2> /dev/null && \
		echo $(PID) killed || \
		echo no running $(CMD)

# if the build fails, running processes will not be affected
restart: build kill bg

watch: restart
	fswatch -o $(SOURCE_CODE) | xargs -n1 -I{} $(MAKE) restart

docker: Dockerfile build-in-docker
	docker build -t $(shell basename $(CURDIR)) .

push: docker
	docker tag $(shell basename $(CURDIR)) $(IMAGE):$(VERSION)
	docker push $(IMAGE):$(VERSION)

