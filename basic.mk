# Set an output prefix, which is the local directory if not specified
PREFIX?=$(shell pwd)

# Set the build dir, where built cross-compiled binaries will be output
BUILDDIR := ${PREFIX}/cross

# Populate version variables
# Add to compile time flags
VERSION := $(shell cat VERSION.txt)
GITCOMMIT := $(shell git rev-parse --short HEAD)
GITUNTRACKEDCHANGES := $(shell git status --porcelain --untracked-files=no)
ifneq ($(GITUNTRACKEDCHANGES),)
	GITCOMMIT := $(GITCOMMIT)-dirty
endif
ifeq ($(GITCOMMIT),)
    GITCOMMIT := ${GITHUB_SHA}
endif
CTIMEVAR=-X $(PKG)/version.GITCOMMIT=$(GITCOMMIT) -X $(PKG)/version.VERSION=$(VERSION)
GO_LDFLAGS=-ldflags "-w $(CTIMEVAR)"
GO_LDFLAGS_STATIC=-ldflags "-w $(CTIMEVAR) -extldflags -static"

# Set our default go compiler
GO := go

# List the GOOS and GOARCH to build
GOOSARCHES = $(shell cat .goosarch)

# Set the graph driver as the current graphdriver if not set.
DOCKER_GRAPHDRIVER := $(if $(DOCKER_GRAPHDRIVER),$(DOCKER_GRAPHDRIVER),$(shell docker info 2>&1 | grep "Storage Driver" | sed 's/.*: //'))
export DOCKER_GRAPHDRIVER

# If this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

.PHONY: build
build: prebuild $(NAME) ## Builds a dynamic executable or package.

$(NAME): $(wildcard *.go) $(wildcard */*.go) VERSION.txt
	@echo "+ $@"
	$(GO) build -tags "$(BUILDTAGS)" ${GO_LDFLAGS} -o $(NAME) .

.PHONY: static
static: prebuild ## Builds a static executable.
	@echo "+ $@"
	CGO_ENABLED=$(CGO_ENABLED) GO111MODULE=off $(GO) build \
				-tags "$(BUILDTAGS) static_build" \
				${GO_LDFLAGS_STATIC} -o bin/$(NAME) main.go

.PHONY: staticvendor
staticvendor: prebuild ## Builds a static executable.
	@echo "+ $@"
	CGO_ENABLED=$(CGO_ENABLED) GO111MODULE=off $(GO) build \
				-tags "$(BUILDTAGS) static_build" \
				${GO_LDFLAGS_STATIC} -o bin/$(NAME) .

all: clean build fmt lint test staticcheck vet install ## Runs a clean, build, fmt, lint, test, staticcheck, vet and install.

.PHONY: fmt
fmt: ## Verifies all files have been `gofmt`ed.
	@echo "+ $@"
	@gofmt -s -l . | grep -v '.pb.go:' | grep -v vendor | tee /dev/stderr

.PHONY: lint
lint: ## Verifies `golint` passes.
	@echo "+ $@"
	@golint ./... | grep -v '.pb.go:' | grep -v vendor | tee /dev/stderr

.PHONY: test
test: prebuild ## Runs the go tests.
	@echo "+ $@"
	@GO111MODULE=off $(GO) test -v -tags "$(BUILDTAGS) cgo" $(shell GO111MODULE=off $(GO) list ./... | grep -v vendor)

.PHONY: vet
vet: ## Verifies `go vet` passes.
	@echo "+ $@"
	@GO111MODULE=off $(GO) vet $(shell GO111MODULE=off $(GO) list ./... | grep -v vendor) | grep -v '.pb.go:' | tee /dev/stderr

.PHONY: staticcheck
staticcheck: ## Verifies `staticcheck` passes.
	@echo "+ $@"
	@staticcheck $(shell $(GO) list ./... | grep -v vendor) | grep -v '.pb.go:' | tee /dev/stderr

.PHONY: cover
cover: prebuild ## Runs go test with coverage.
	@echo "" > coverage.txt
	@GO111MODULE=off $(GO) test -race -v -tags "$(BUILDTAGS) cgo" -coverprofile=coverage.txt $(shell GO111MODULE=off $(GO) list ./... | grep -v vendor)

.PHONY: coverhtml
coverhtml: cover ## Runs go test with coverage, and then displays html
	@GO111MODULE=off $(GO) tool cover -html coverage.txt


.PHONY: install
install: prebuild ## Installs the executable or package.
	@echo "+ $@"
	GO111MODULE=off $(GO) install -a -tags "$(BUILDTAGS)" ${GO_LDFLAGS} .

#@todo convert to go mod
#.PHONY: vendor
#vendor: ## Updates the vendoring directory.
#	@$(RM) go.sum
#	@$(RM) -r vendor
#	GO111MODULE=on $(GO) mod init || true
#	GO111MODULE=on $(GO) mod tidy
#	GO111MODULE=on $(GO) mod vendor

.PHONY: clean
clean: ## Cleanup any build binaries or packages.
	@echo "+ $@"
	$(RM) $(NAME)
	$(RM) -r $(BUILDDIR)

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | sed 's/^[^:]*://g' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

check_defined = \
    $(strip $(foreach 1,$1, \
	$(call __check_defined,$1,$(strip $(value 2)))))

__check_defined = \
    $(if $(value $1),, \
    $(error Undefined $1$(if $2, ($2))$(if $(value @), \
    required by target `$@')))