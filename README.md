# go-make

Makefile for go projects

## Usage

```bash
# build go files
# params:
#   GO_MAIN: the entry file, default to main.go
#   OS: GOOS, default to `go env GOOS`
#   ARCH: GOARCH, default to `go env GOARCH`
#   BINARY: the name of the output, defaults to the dirctory name
# built binary will be `build/$(OS)_$(ARCH)/$(BINARY)`
make build
```
