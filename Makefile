.PHONY: build 

# Latest git tag
LAST_VER := $(shell git describe --abbrev=0 --tags 2>/dev/null || echo untagged)
IS_DIRTY := $(shell git diff --quiet --ignore-submodules HEAD; echo $$?)
IS_LATEST := $(shell test $(IS_DIRTY) -eq 0 && \
	test `git rev-list -n 1 HEAD 2>/dev/null` = `git rev-list -n 1 $(LAST_VER) 2>/dev/null` && \
	echo 1 || echo 0)
VERSION := $(shell test $(IS_LATEST) -eq 1 && \
	echo $(LAST_VER) || echo dev)
GITHASH := $(shell test $(IS_DIRTY) -eq 0 && \
	echo `git rev-parse HEAD` || echo `git rev-parse HEAD`-dirty)

IMPORT_PATH := $(shell go list)
GO_DIRS := $(shell go list -f "{{ .Name }}" ./* 2>/dev/null | grep -v main | xargs) $(shell ls | grep vendor)

GO_VERSION := 1.8

OS := $(shell go env GOOS)
ARCH := $(shell go env GOARCH)
CGO := 0
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
	@ echo "  	  CGO: CGO_ENABLED, default is 0"
	@ echo "	built binary will be \`build/OS_ARCH/BINARY\`"
	@ echo ""
	@ echo "docker:	build docker image"
	@ echo "	image name is set using $$IMAGE"
	@ echo ""
	@ echo "push:	push docker image"
	@ echo "	push $$IMAGE"

build: 
	@ $(MAKE) build/$(OS)_$(ARCH)

build/%: 
	CGO_ENABLED=$(CGO) GOOS=$(OS) GOARCH=$(ARCH) \
		go build -o $(BIN) -i -ldflags "$(LDFLAGS)" --tags "$(TAGS)" \
		$(GO_MAIN)

build-in-docker: 
	docker run --rm \
		-v $(GOPATH)/src:/go/src \
		-w /go/src/$(IMPORT_PATH) \
		golang:$(GO_VERSION) \
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
	fswatch -o $(GO_DIRS) | xargs -n1 -I{} $(MAKE) restart

# docker: Dockerfile build-in-docker
docker: 
	$(MAKE) build OS=linux ARCH=amd64
	docker build -t $(shell basename $(CURDIR)) .

push: docker
	docker tag $(shell basename $(CURDIR)) $(IMAGE):$(VERSION)
	docker push $(IMAGE):$(VERSION)

