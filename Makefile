.PHONY: build 

# last git tag
LAST_VER := $(shell git describe --abbrev=0 --tags 2>/dev/null || echo untagged)
# whether the repo is dirty
IS_DIRTY := $(shell git diff --quiet --ignore-submodules HEAD; echo $$?)
# whether the repo is on the latest tag
IS_LATEST := $(shell test $(IS_DIRTY) -eq 0 && \
	test `git rev-list -n 1 HEAD 2>/dev/null` = `git rev-list -n 1 $(LAST_VER) 2>/dev/null` && \
	echo 1 || echo 0)
# current git revision
GITHASH := $(shell test $(IS_DIRTY) -eq 0 && \
	echo `git rev-parse HEAD` || echo `git rev-parse HEAD`-dirty)
# repo version
VERSION := $(shell test $(IS_LATEST) -eq 1 && \
	echo $(LAST_VER) || echo dev)

# directory that has go code
GO_DIRS := $(shell go list -f "{{ .Name }}" ./* 2>/dev/null | grep -v main | xargs) $(shell ls | grep vendor)
# GOOS
OS := $(shell go env GOOS)
# GOARCH
ARCH := $(shell go env GOARCH)
# CGO_ENABLED
CGO := 0
# entry file
GO_MAIN := main.go
# compiled binary name
BINARY := $(shell realpath $(GO_MAIN) | xargs dirname | xargs basename)
# name for rpm package
RPM_NAME := $(BINARY)
# relative path of compiled binary
BIN := build/$(OS)_$(ARCH)/$(BINARY)
# build command for build-in-docker
BUILD_CMD := make build OS=$(OS) ARCH=$(ARCH)
# golang docker image version
GO_VERSION := 1.8

DOCKERFILE := Dockerfile

IMAGE_NAME := $(shell basename $(CURDIR))

PID := $(shell test -e tmp/$(CMD).pid && cat tmp/$(CMD).pid)
# whether to use docker
DOCKER := 0
ifeq ($(DOCKER), 1)
build_target := build-in-docker
else
build_target := build/$(OS)_$(ARCH)
endif

help:
	@ echo "build:	build go files"
	@ echo "	params:"
	@ echo "  	  GO_MAIN: the entry file, default to main.go"
	@ echo "  	  OS: GOOS"
	@ echo "  	  ARCH: GOARCH"
	@ echo "  	  BINARY: the name of the output, defaults to the dirctory name"
	@ echo "  	  CGO: CGO_ENABLED, default is 0"
	@ echo "	built binary will be \`build/OS_ARCH/BINARY\`"
	@ echo ""
	@ echo "docker:	build docker image"
	@ echo "	image name is set using $$IMAGE"
	@ echo ""
	@ echo "push:	push docker image"
	@ echo "	push $$IMAGE"

build: 
	@ $(MAKE) $(build_target) -B

build/%: 
	@ echo "Building $(BIN)"
	@ CGO_ENABLED=$(CGO) GOOS=$(OS) GOARCH=$(ARCH) \
		go build -o $(BIN) -i -ldflags "$(LDFLAGS)" --tags "$(TAGS)" \
		$(GO_MAIN)

build-in-docker: 
	@ echo "Building $(BIN) in docker"
	@ echo "Entering docker container"
	@ docker run --rm \
		-v $(GOPATH)/src:/go/src \
		-w /go/src/$(shell go list) \
		golang:$(GO_VERSION) \
		bash -c "$(BUILD_CMD)"
	@ echo "Leaving docker container"

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
	fswatch -o $(GO_DIRS) | xargs -n1 -I{} $(MAKE) restart

docker: 
	@ $(MAKE) build-in-docker OS=linux ARCH=amd64
	@ echo "Building docker container"
	@ docker build -t $(IMAGE_NAME) -f $(DOCKERFILE) .

push: docker
	docker tag $(IMAGE_NAME) $(IMAGE):$(VERSION)
	docker push $(IMAGE):$(VERSION)

ifeq (dev, $(VERSION))
rpm_version := $(LAST_VER).dev$(shell date +%s)
else
rpm_version := $(VERSION)
endif

FPM := docker run -it --rm -v `pwd`:/fpm docker.elenet.me/yuelong.huang/fpm:alpine

rpm:
	@ mkdir -p dist
	@ $(MAKE) build OS=linux ARCH=amd64
	@ $(FPM) -s dir -t rpm -n $(RPM_NAME) -f -p dist \
		--rpm-os=linux -v $(rpm_version) $(rpm_args) \
		$(rpm_files)

